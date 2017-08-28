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
        |> Stream.map(fn {_user_id, visit_id} ->
          visit = Round1.Db.V.get(visit_id)
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
    if old.user != new.user do
      GenServer.call(__MODULE__, {:update, old, new})
    end
  end

  def load_data(nil), do: nil
  def load_data(data) do
    data = data
    |> Enum.map(& {&1.user, &1.id})

    :ets.insert(@table, data)
  end

  ### callbacks
  def init(_) do
    t = :ets.new(@table, [:bag, :named_table, :public, read_concurrency: true])
    {:ok, t}
  end

  def handle_call({:add, visit}, _from, state) do
    :ets.insert(@table, {visit.user, visit.id})
    {:reply, :ok, state}
  end

  def handle_call({:update, old, new}, _from, state) do
    :ets.delete_object(@table, {old.user, old})
    :ets.insert(@table, {new.user, new.id})
    {:reply, :ok, state}
  end

end
