import Config

if config_env() == :prod or :dev do
  config_json = Path.expand("~/.rr/config.json") |> File.read!() |> JSON.decode!()

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
    rancher_token: config["rancher_token"]
end
