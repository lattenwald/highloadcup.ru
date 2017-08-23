# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :round1,
  port: 8080,

  # for test purposes phase_*.answ should reside nearby, in /path/to/answers/*.answ
  datafile: "/path/to/data.zip"
