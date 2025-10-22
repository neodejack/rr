import Config

if config_env() == :prod or config_env() == :dev do
  config_path = Path.expand("~/.rr/config.json")
  config_json = config_path |> File.read!() |> JSON.decode!()

  parse_func = fn config ->
    case config do
      %{
        "rancher_hostname" => _,
        "rancher_token" => _
      } ->
        config

      true ->
        raise "config file not right"
    end
  end

  config = parse_func.(config_json)

  config :rr, RR,
    rancher_hostname: config["rancher_hostname"],
    rancher_token: config["rancher_token"],
    config_path: config_path
end
