defmodule Round1.Db do
  require Logger
  import Supervisor.Spec

  @datadir Application.fetch_env!(:round1, :datadir)
  @options_file Path.join(@datadir, "options.txt")
  @table :timestamp_ets

  ### interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
    Supervisor.start_link(__MODULE__, nil)
  end

  def get(:users, id), do: Round1.Db.U.get(id)
  def get(:visits, id), do: Round1.Db.V.get(id)
  def get(:locations, id), do: Round1.Db.L.get(id)

  def update(:users, id, json), do: Round1.Db.U.update(id, json)
  def update(:locations, id, json), do: Round1.Db.L.update(id, json)
  def update(:visits, id, json), do: Round1.Db.V.update(id, json)

  def insert(:users, id, json), do: Round1.Db.U.insert(id, json)
  def insert(:visits, id, json), do: Round1.Db.V.insert(id, json)
  def insert(:locations, id, json), do: Round1.Db.L.insert(id, json)

  def merge(nil, _), do: nil
  def merge(_, %{"id" => _}), do: :error
  def merge(old, new) do
    try do
      Enum.reduce(
        new, old,
        fn {k, v}, acc -> Map.replace!(acc, k, v) end
      )
    rescue
      _other ->
        # Logger.warn "#{__MODULE__} merge #{inspect other}, old: #{inspect old}, new: #{inspect new}"
        :error
    else
      new_item -> new_item
    end
  end

  def timestamp do
    case :ets.lookup(@table, :timestamp) do
      [] -> raise "no :timestamp"
      [{:timestamp, timestamp}] -> timestamp
    end
  end

  def now do
    case :ets.lookup(@table, :now) do
      [] -> raise "no :now"
      [{:now, now}] -> now
    end
  end

  ### callbacks
  def init(_) do
    children = [
      worker(Round1.Db.Time, []),
      worker(Round1.Db.U, []),
      worker(Round1.Db.V, []),
      worker(Round1.Db.L, []),
      worker(Round1.Db.Visits, []),
      worker(Round1.Db.Avg, []),
    ]

    res = supervise(children, strategy: :one_for_one, name: __MODULE__)
    spawn fn ->
      # fugly hack
      start = Timex.now
      :timer.sleep 1000
      load_dir(@datadir)
      finish = Timex.now
      Logger.info "done loading in #{Timex.diff finish, start, :seconds} seconds"
    end
    res
  end

  ### loading data
  def load_dir(dirname) do
    Path.wildcard("#{dirname}/**/*.json")
    |> Flow.from_enumerable
    |> Flow.partition
    |> Flow.each(&load_file/1)
    |> Flow.run

    load_options(@options_file)

    Logger.info "Data timestamp is #{timestamp()}"
  end

  def load_options(file) do
    timestamp = file |> File.read! |> String.split("\n") |> List.first |> String.to_integer
    now = Timex.from_unix timestamp

    pid = Round1.Db.Time.pid()

    :ets.new(@table, [:set, :named_table, {:heir, pid, nil}, read_concurrency: true])
    :ets.insert(@table, {:timestamp, timestamp})
    :ets.insert(@table, {:now, now})
  end

  def load_file(filename) do
    Logger.info "loading #{filename}..."
    filename
    |> File.read!
    |> load_binary
    Logger.info "...loaded #{filename}"
  end

  def load_binary(data) do
    data
    |> Poison.decode!(keys: :atoms)
    |> load_data
  end

  defp load_data(data) do
    Round1.Db.U.load_data(data[:users])
    Round1.Db.L.load_data(data[:locations])
    Round1.Db.V.load_data(data[:visits])

    Round1.Db.Visits.load_data(data[:visits])
    Round1.Db.Avg.load_data(data[:visits])
  end

end
