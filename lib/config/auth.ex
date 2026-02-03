defmodule RR.Config.Auth do
  @moduledoc false
  alias RR.Config
  alias RR.Shell

  defstruct [:rancher_hostname, :rancher_token]

  def get_auth do
    auth = %__MODULE__{
      rancher_hostname: Config.get("rancher_hostname"),
      rancher_token: Config.get("rancher_token")
    }

    if auth.rancher_hostname != nil and auth.rancher_token != nil do
      {:ok, auth}
    else
      {:error, "auth config file incomplete\nto login, run: rr login"}
    end
  end

  def put_auth(auth) do
    Config.put("rancher_hostname", auth.rancher_hostname)
    Config.put("rancher_token", auth.rancher_token)
  end

  def ensure_valid_auth do
    with {:ok, auth} <- get_auth(),
         {:ok, token_info} <- External.RancherHttpClient.get_token_info(auth),
         {:ok, _token_description} <- ensure_token_info_valid(token_info) do
      {:ok, auth}
    end
  end

  def ensure_token_info_valid(token_info) do
    with false <- token_info.expired,
         true <- token_info.enabled do
      creation_ts = DateTime.from_unix!(token_info.created_ts, :millisecond)
      expiration_ts = DateTime.add(creation_ts, token_info.ttl, :millisecond)

      if DateTime.before?(DateTime.utc_now(), expiration_ts) do
        if DateTime.diff(expiration_ts, DateTime.utc_now()) < 604_800 do
          Shell.error("warning: rancher token will expire in less than 7 days. run rr login to input a renewed token")
          Shell.error("expiration time: #{DateTime.to_string(expiration_ts)}")
        end

        {:ok, token_info.description}
      else
        {:error, "rancher token has expired. run rr login to input a valid token"}
      end
    else
      _ -> {:error, "rancher token is not valid. run rr login to input a valid token"}
    end
  end
end
