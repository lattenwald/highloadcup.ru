defmodule Round1.Db do
  require Logger
  use Agent, restart: :transient

  @datafile Application.fetch_env!(:round1, :datafile)

  ### interface
  def start_link() do
    Logger.debug "#{__MODULE__} starting"
    res = {:ok, _} = Agent.start_link(
      fn -> %{users: %{}, locations: %{}, visits: %{}} end,
      name: __MODULE__
    )
    load_zip(@datafile)
    res
  end

  def get_state, do: Agent.get(__MODULE__, & &1)

  def get(type, id) do
    Agent.get(
      __MODULE__,
      fn state ->
        case state[type] do
          nil -> nil
          data -> data[id]
        end
      end
    )
  end

  ### loading data
  def load_dir(dirname) do
    for file <- File.ls!(dirname),
      Path.extname(file) == ".json",
      file = Path.join(dirname, file) do
        Logger.debug file
        if File.dir?(file) do
          load_dir(file)
        else
          load_file(file)
        end
    end
  end

  def load_file(filename) do
    filename
    |> File.read!
    |> load_binary
  end

  def load_zip(filename) do
    {:ok, files} = :zip.extract(String.to_charlist(filename), [:memory])
    for {file, data} <- files,
      Path.extname(file) == ".json" do
        load_binary(data)
    end
  end

  def load_binary(data) do
    data
    |> Poison.decode!(keys: :atoms)
    |> load_data
  end

  defp load_data(data) do
    load_data(:users, data[:users])
    load_data(:locations, data[:locations])
    load_data(:visits, data[:visits])

    Round1.Db.Visits.add_visits(data[:visits])
    Round1.Db.Avg.add_visits(data[:visits])
  end

  defp load_data(_key, nil), do: :ok
  defp load_data(key, data) do
    for item <- data do
      Agent.update(
        __MODULE__,
        fn state ->
          %{ state | key => Map.put(state[key], item.id, item)}
        end
      )
    end
  end

end

defmodule Round1.Db.Visits do
  require Logger
  use Agent, restart: :transient

  alias Round1.Db

  @moduledoc """
  Storage has map from user id to visits.
  Visits is a list of {visit, location} and flag `sorted`.
  On `get` sort it if it isn't sorted yet and set the flag.
  On `put`, set `sorted=false`.
  """

  defstruct sorted: false, visits: []

  ### interface
  def start_link() do
    Logger.debug "#{__MODULE__} starting"
    Agent.start_link(
      fn -> %{} end,
      name: __MODULE__
    )
  end

  def get_state(), do: Agent.get(__MODULE__, & &1)

  def add_visits(nil), do: :ok
  def add_visits(data), do: Enum.map(data, &add_visit(&1))

  def add_visit(visit) do
    Agent.update(
      __MODULE__,
      fn state ->
        Map.update(
          state, visit.user,
          %__MODULE__{sorted: false, visits: [visit]},
          & %{ &1 | sorted: false, visits: [ visit | &1.visits ]}
        )
      end
    )
  end

  def get(user_id, opts \\ []) do
    from_date   = opts[:from_date]
    to_date     = opts[:to_date]
    country     = opts[:country]
    to_distance = opts[:to_distance]

    cond do
      is_nil(Db.get(:users, user_id)) -> nil

      true ->
        visits = get_visits(user_id)
        |> Stream.map(fn visit ->
          loc = Db.get(:locations, visit.location)
          %{visit | location: loc}
        end)
        |> Stream.filter(& is_nil(country) || &1.location.country == country)
        |> Stream.filter(& is_nil(to_distance) || &1.location.distance < to_distance)
        |> Stream.map(& %{mark: &1.mark, visited_at: &1.visited_at, place: &1.location.place})
        |> Stream.filter(& is_nil(from_date) || &1.visited_at > from_date)
        |> Stream.filter(& is_nil(to_date) || &1.visited_at < from_date)
        |> Enum.into([])
    end
  end

  defp get_visits(user_id) do
    Agent.get_and_update(
      __MODULE__,
      fn state ->
        case state[user_id] do
          nil -> {[], state}
          %{sorted: true, visits: visits} -> {visits, state}
          %{visits: visits} ->
            new_visits = Enum.sort_by(visits, & &1.visited_at)
            new_state = Map.update!(
              state, user_id,
              & %{&1 | sorted: true, visits: new_visits}
            )
            {new_visits, new_state}
        end
      end
    )
  end

end

defmodule Round1.Db.Avg do
  require Logger
  use Agent, restart: :transient

  alias Round1.Db

  @moduledoc """
  Storage has map from location_id to visits
  """

  ### interface
  def start_link() do
    Logger.debug "#{__MODULE__} starting"
    Agent.start_link(
      fn -> %{} end,
      name: __MODULE__
    )
  end

  def get_state(), do: Agent.get(__MODULE__, & &1)
  def add_visits(nil), do: :ok
  def add_visits(data), do: Enum.map(data, &add_visit(&1))

  def add_visit(visit) do
    Agent.update(
      __MODULE__,
      fn state ->
        Map.update(
          state, visit.location, [visit],
          & [visit | &1]
        )
      end
    )
  end

  def get(location_id, opts \\ []) do
    from_date = opts[:from_date]
    to_date   = opts[:to_date]

    {{y, m, d}, t} = :erlang.localtime
    born_before = case opts[:from_age] do
                    nil -> nil
                    age -> to_timestamp {{y - age, m, d}, t}
                  end
    born_after  = case opts[:to_age] do
                    nil -> nil
                    age -> to_timestamp {{y - age, m, d}, t}
                  end

    gender    = opts[:gender]

    cond do
      is_nil(Db.get(:locations, location_id)) -> nil

      true ->
        {total, cnt} = get_visits(location_id)
        |> Stream.filter(& is_nil(from_date) || &1.visited_at > from_date)
        |> Stream.filter(& is_nil(to_date) || &1.visited_at < from_date)
        |> Stream.map(fn visit ->
          user = Db.get(:users, visit.user)
          %{visit | user: user}
        end)
        |> Stream.filter(& is_nil(gender) || &1.user.gender == gender)
        |> Stream.filter(& is_nil(born_before) || &1.user.birth_date < born_before)
        |> Stream.filter(& is_nil(born_after)  || &1.user.birth_date > born_after)
        |> Enum.reduce({0, 0}, fn visit, {total, cnt} -> {total+visit.mark, cnt+1} end)

        if cnt == 0, do: 0, else: total / cnt
    end
  end

  defp get_visits(location_id) do
    Agent.get(
      __MODULE__,
      & &1[location_id]
    ) || []
  end

  # https://stackoverflow.com/questions/12527908/how-to-convert-datetime-to-timestamp-in-erlang
  defp to_timestamp(datetime) do
    (:calendar.datetime_to_gregorian_seconds(datetime) - 62167219200)*1000000
  end

end
