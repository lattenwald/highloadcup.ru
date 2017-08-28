defmodule Round1.Db.Time do
  use GenServer, restart: :transient

  def start_link(), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def pid(), do: GenServer.call(__MODULE__, :pid)

  def handle_call(:pid, _from, state), do: {:reply, self(), state}

  def handle_info({:"ETS-TRANSFER", :timestamp_ets, _pid, _data}, state), do: {:noreply, state}
end
