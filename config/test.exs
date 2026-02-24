import Config

System.put_env("RR_HOME", "~/.rr/test")

config :rr, :external_bound, Mock
config :rr, :run_cli, false
