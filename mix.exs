defmodule Round1.Mixfile do
  use Mix.Project

  def project do
    [
      app: :round1,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Round1.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elli, "~> 2.0"},
      {:timex, "~> 3.1"},
      {:distillery, "~> 1.5"},
      {:flow, "~> 0.12.0"},

      {:jiffy, "~> 0.14.11"},
      {:atomic_map, "~> 0.9.2"},

      {:httpoison, "~> 0.13.0", only: :test},
      {:poison, "~> 3.1", only: :test},
    ]
  end
end
