defmodule Round1.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Supervisor.Spec


  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      worker(Round1.Db.Visits, []),
      worker(Round1.Db.Avg, []),
      worker(Round1.Db, []),
      worker(Round1.Handler, []),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Round1.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
