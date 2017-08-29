defmodule Round1.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Supervisor.Spec

  @port Application.get_env(:round1, :port, 80)

  def start(_type, _args) do
    elli_opts = [callback: Round1.Handler, port: @port]

    # List all child processes to be supervised
    children = [
      supervisor(Round1.Db, []),
      worker(:elli, [elli_opts], restart: :permanent),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Round1.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
