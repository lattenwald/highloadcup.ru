defmodule Round1.Db.V do
  require Logger
  use GenServer, restart: :transient

  @compile {:parse_transform, :ms_transform} # for :ets.fun2ms

  @table :visits

  ### interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, _user, _location, item}] -> item
      [] -> nil
    end
  end

  def get_for_user(user_id, opts \\ []) do
    case Round1.Db.U.get(user_id) do
      nil -> nil

      _user ->
        from_date   = opts[:from_date]
        to_date     = opts[:to_date]
        country     = opts[:country]
        to_distance = opts[:to_distance]

        match_spec = :ets.fun2ms(fn {_id, ^user_id, _loc, item} -> item end)
        :ets.select(@table, match_spec)
        |> Stream.map(fn visit ->
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


  def avg(location_id, opts \\ []) do
    case Round1.Db.L.get(location_id) do
      nil -> nil

      _loc ->
        from_date = opts[:from_date]
        to_date   = opts[:to_date]
        now = Timex.now
        born_before = case opts[:from_age] do
                        nil -> nil
                        age -> now |> Timex.shift(years: -age) |> Timex.to_unix
                      end
        born_after  = case opts[:to_age] do
                        nil -> nil
                        age -> now |> Timex.shift(years: -age) |> Timex.to_unix
                      end
        gender    = opts[:gender]

        match_spec = :ets.fun2ms(fn {_id, _user_id, ^location_id, item} -> item end)

        {total, cnt} = :ets.select(@table, match_spec)
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

  def insert(id, data) do
    GenServer.call(__MODULE__, {:insert, id, data})
  end

  def update(id, json) do
    case get(id) do
      nil  -> nil
      _old -> GenServer.call(__MODULE__, {:update, id, json})
    end
  end

  ### callbacks
  def init(_) do
    t = :ets.new(@table, [:set, :named_table, read_concurrency: true])
    {:ok, t}
  end

  def handle_call({:insert, id, data}, _from, state) do
    res = :ets.insert_new(@table, {id, data.user, data.location, data}) && :ok || :error
    {:reply, res, state}
  end

  def handle_call({:update, id, json}, _from, state) do
    resp =
      case get(id) do
        nil -> nil
        old ->
          case Round1.Db.merge(old, json) do
            new=%{} ->
              :ets.insert(@table, {id, new.user, new.location, new})
              :ok

            other   -> other # nil or :error
          end
      end
    {:reply, resp, state}
  end

  def handle_call({:load, data}, _from, state) do
    for item <- data, do: :ets.insert(@table, {item.id, item.user, item.location, item})
    {:reply, :ok, state}
  end

  ### loading
  @doc false
  def load_data(nil), do: nil
  def load_data(data) do
    GenServer.call(__MODULE__, {:load, data})
  end

end
