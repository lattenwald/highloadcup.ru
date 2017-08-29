defmodule Round1.Db.Avg do
  @moduledoc """
  ets table stores a bag of location_id to visit
  """

  require Logger
  use GenServer, restart: :transient

  @table :visits_avg

  ### interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
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

  def get(location_id, opts \\ []) do
    case Round1.Db.L.get(location_id) do
      nil -> nil

      _loc ->
        from_date = opts[:from_date]
        to_date   = opts[:to_date]
        now = Round1.Db.now
        # now = Timex.now
        born_before = case opts[:from_age] do
                        nil -> nil
                        age -> now |> Timex.shift(years: -age) |> Timex.to_unix
                      end
        born_after  = case opts[:to_age] do
                        nil -> nil
                        age -> now |> Timex.shift(years: -age) |> Timex.to_unix
                      end
        gender    = opts[:gender]

        {total, cnt} = :ets.lookup(@table, location_id)
        |> Stream.map(fn {_location_id, visit_id} -> Round1.Db.V.get(visit_id) end)
        |> Stream.filter(& is_nil(from_date) || &1.visited_at > from_date)
        |> Stream.filter(& is_nil(to_date) || &1.visited_at < to_date)
        |> Stream.map(fn visit ->
          user = Round1.Db.U.get(visit.user)
          %{visit | user: user}
        end)
        |> Stream.filter(& is_nil(gender) || &1.user.gender == gender)
        |> Stream.filter(& is_nil(born_before) || &1.user.birth_date < born_before)
        |> Stream.filter(& is_nil(born_after)  || &1.user.birth_date > born_after)
        |> Enum.reduce({0, 0}, fn visit, {total, cnt} -> {total+visit.mark, cnt+1} end)

        if cnt == 0, do: 0, else: round((total / cnt) * 100000) / 100000
    end
  end

  def get_raw(location_id, opts \\ []) do
    case Round1.Db.L.get(location_id) do
      nil -> nil

      _loc ->
        from_date = opts[:from_date]
        to_date   = opts[:to_date]
        now = Round1.Db.now
        # now = Timex.now
        born_before = case opts[:from_age] do
                        nil -> nil
                        age -> now |> Timex.shift(years: -age) |> Timex.to_unix
                      end
        born_after  = case opts[:to_age] do
                        nil -> nil
                        age -> now |> Timex.shift(years: -age) |> Timex.to_unix
                      end
        gender    = opts[:gender]

        :ets.lookup(@table, location_id)
        |> Stream.map(fn {_location_id, visit_id} -> Round1.Db.V.get(visit_id) end)
        |> Stream.filter(& is_nil(from_date) || &1.visited_at > from_date)
        |> Stream.filter(& is_nil(to_date) || &1.visited_at < to_date)
        |> Stream.map(fn visit ->
          user = Round1.Db.U.get(visit.user)
          %{visit | user: user}
        end)
        |> Stream.filter(& is_nil(gender) || &1.user.gender == gender)
        |> Stream.filter(& is_nil(born_before) || &1.user.birth_date < born_before)
        |> Stream.filter(& is_nil(born_after)  || &1.user.birth_date > born_after)
        |> Enum.into([])
    end
  end

  def update(old, new) do
    if old.location != new.location do
      GenServer.call(__MODULE__, {:update, old, new})
    end
  end

  def load_data(nil), do: nil
  def load_data(data) do
    data = data
    |> Enum.map(& {&1.location, &1.id})

    :ets.insert(@table, data)
  end

  ### callbacks
  def init(_) do
    t = :ets.new(@table, [:bag, :named_table, :public, :compressed, read_concurrency: true])
    {:ok, t}
  end

  def handle_call({:add, visit}, _from, state) do
    :ets.insert(@table, {visit.location, visit.id})
    {:reply, :ok, state}
  end

  def handle_call({:update, old, new}, _from, state) do
    :ets.delete_object(@table, {old.location, old.id})
    :ets.insert(@table, {new.location, new.id})
    {:reply, :ok, state}
  end


end
