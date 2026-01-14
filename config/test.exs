import Config

System.put_env("RR_HOME", "~/.rr/test")

config :rr, RR, enabled: false
config :rr, :external_bound, Mock
