import Config

config_path = Path.expand("~/.rr/config.toml")

config_map =
  case Toml.decode_file(config_path, []) do
    {:ok, contents} -> contents
    {:error, reason} ->
      message = if is_binary(reason), do: reason, else: inspect(reason)
      raise "Unable to parse #{config_path}: #{message}"
  end

rancher_config =
  case config_map do
    %{"rancher" => section} -> section
    _ -> raise "Missing [rancher] section in #{config_path}"
  end

hostname =
  case rancher_config do
    %{"hostname" => value} -> value
    _ -> raise "Missing hostname entry under [rancher] in #{config_path}"
  end

token =
  case rancher_config do
    %{"token" => value} -> value
    _ -> raise "Missing token entry under [rancher] in #{config_path}"
  end

config :rr,
  rancher_hostname: hostname,
  rancher_token: token
