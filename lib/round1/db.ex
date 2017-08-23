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
      fn state -> state[type][id] end
    )
  end

  def update(type, id, json) do
    Agent.get_and_update(
      __MODULE__,
      fn state ->
        old = state[type][id]
        case merge(state[type][id], json) do
          nil -> {nil, state}
          :error -> {:error, state}
          new -> {{:ok, type, old, new}, %{state | type => Map.replace(state[type], id, new)}}
        end
      end
    ) |> case do
           {:ok, :visits, old, new} ->
             Round1.Db.Visits.update(old, new)
             Round1.Db.Avg.update(old, new)
             :ok
           {:ok, _, _, _} -> :ok
           other -> other
         end
  end

  def insert(type, id, data) do
    if get(type, id) do
      :error
    else
      load_data(type, [data])
      if type == :visits do
        Round1.Db.Visits.add_visit(data)
        Round1.Db.Avg.add_visit(data)
      end
      :ok
    end
  end

  defp merge(nil, _), do: nil
  defp merge(_, %{"id" => _}), do: :error
  defp merge(old, new) do
    try do
      Enum.reduce(
        new, old,
        fn {k, v}, acc -> Map.replace!(acc, String.to_existing_atom(k), v) end
      )
    rescue
      other ->
        Logger.warn "#{__MODULE__} merge #{inspect other}, old: #{inspect old}, new: #{inspect new}"
        :error
    else
      new_item -> new_item
    end
  end

  ### loading data
  def load_dir(dirname) do
    for file <- File.ls!(dirname),
      Path.extname(file) == ".json",
      file = Path.join(dirname, file) do
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
