defmodule Round1.Db do
  require Logger
  import Supervisor.Spec

  @datafile Application.fetch_env!(:round1, :datafile)

  ### interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
    Supervisor.start_link(__MODULE__, nil)
  end

  def get(:users, id), do: Round1.Db.U.get(id)
  def get(:visits, id), do: Round1.Db.V.get(id)
  def get(:locations, id), do: Round1.Db.L.get(id)

  def update(:users, id, json), do: Round1.Db.U.update(id, json)
  def update(:visits, id, json), do: Round1.Db.V.update(id, json)
  def update(:locations, id, json), do: Round1.Db.L.update(id, json)

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

  ### callbacks
  def init(_) do
    children = [
      worker(Round1.Db.U, []),
      worker(Round1.Db.V, []),
      worker(Round1.Db.L, []),
    ]

    res = supervise(children, strategy: :one_for_one, name: __MODULE__)
    spawn fn ->
      # fugly hack
      :timer.sleep 1000
      load_zip(@datafile)
    end
    res
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
    Round1.Db.U.load_data(data[:users])
    Round1.Db.L.load_data(data[:locations])
    Round1.Db.V.load_data(data[:visits])
  end

end
