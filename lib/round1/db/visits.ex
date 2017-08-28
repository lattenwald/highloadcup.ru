defmodule Round1.Db.Visits do
  @moduledoc """
  ets table stores a bag of user_id to visit
  """

  require Logger
  use GenServer, restart: :transient

  @table :visits_user

  ### interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get(user_id, opts \\ []) do
    case Round1.Db.U.get(user_id) do
      nil -> nil

      _user ->
        from_date   = opts[:from_date]
        to_date     = opts[:to_date]
        country     = opts[:country]
        to_distance = opts[:to_distance]

        :ets.lookup(@table, user_id)
        |> Stream.map(fn {_user_id, visit} ->
          loc = Round1.Db.L.get(visit.location)
          %{visit | location: loc}
        end)
        |> Stream.filter(& is_nil(country) || &1.location.country == country)
        |> Stream.filter(& is_nil(to_distance) || &1.location.distance < to_distance)
        |> Stream.map(& %{mark: &1.mark, visited_at: &1.visited_at, place: &1.location.place})
        |> Stream.filter(& is_nil(from_date) || &1.visited_at > from_date)
        |> Stream.filter(& is_nil(to_date) || &1.visited_at < to_date)
        |> Enum.sort_by(& &1.visited_at)
    end
  end

  def add(visit) do
    case Round1.Db.U.get(visit.user) do
      nil -> nil
      _user ->
        GenServer.call(__MODULE__, {:add, visit})
    end
  end

  def add!(visit) do
    GenServer.call(__MODULE__, {:add, visit})
  end

  def update(old, new) do
    GenServer.call(__MODULE__, {:update, old, new})
  end

  def load_data(nil), do: nil
  def load_data(data), do: GenServer.call(__MODULE__, {:load, data})

  ### callbacks
  def init(_) do
    t = :ets.new(@table, [:bag, :named_table, read_concurrency: true])
    {:ok, t}
  end

  def handle_call({:add, visit}, _from, state) do
    :ets.insert(@table, {visit.user, visit})
    {:reply, :ok, state}
  end

  def handle_call({:update, old, new}, _from, state) do
    :ets.delete_object(@table, {old.user, old})
    :ets.insert(@table, {new.user, new})
    {:reply, :ok, state}
  end

  def handle_call({:load, data}, _from, state) do
    for item <- data, do: :ets.insert(@table, {item.user, item})
    {:reply, :ok, state}
  end


end
