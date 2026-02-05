import Config

System.put_env("RR_HOME", "~/.rr/test")

config :rr, RR, enabled: false
config :rr, :external_bound, Mock
config :rr, :raise_on_error, true
