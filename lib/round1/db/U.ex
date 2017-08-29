defmodule Round1.Db.U do
  require Logger
  use GenServer, restart: :transient

  @table :users

  ### interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, item}] -> item
      [] -> nil
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
    t = :ets.new(@table, [:set, :named_table, :public, :compressed, read_concurrency: true])
    {:ok, t}
  end

  def handle_call({:insert, id, data}, _from, state) do
    res = :ets.insert_new(@table, {id, data}) && :ok || :error
    {:reply, res, state}
  end

  def handle_call({:update, id, json}, _from, state) do
    resp =
      case get(id) do
        nil -> nil
        old ->
          case Round1.Db.merge(old, json) do
            new=%{} ->
              :ets.insert(@table, {id, new})
              :ok

            other   -> other # nil or :error
          end
      end
    {:reply, resp, state}
  end

  ### loading
  @doc false
  def load_data(nil), do: nil
  def load_data(data) do
    :ets.insert(@table, Enum.map(data, & {&1.id, &1}))
  end

end
