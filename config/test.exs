import Config

config :rr, RR,
  enabled: false,
  rancher_hostname: System.get_env("RANCHER_HOSTNAME"),
  rancher_token: System.get_env("RANCHER_TOKEN"),
  config_path: Path.expand("~/.rr/test/config.json")
