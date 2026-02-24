import Config

System.put_env("RR_HOME", "~/.rr/test")

config :rr, :external_bound, Mock
# TODO: remove in phase 2 when Shell.raise is eliminated
config :rr, :raise_on_error, true
config :rr, :run_cli, false
