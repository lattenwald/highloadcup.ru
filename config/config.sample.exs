# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  level: :warn

config :round1,
  port: 80,

  # path to unzipped data
  # `options.txt` is expected to be in that directory as well
  datadir: "/path/to/data"

config :tzdata, :autoupdate, :disabled
