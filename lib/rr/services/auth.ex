defmodule RR.Services.Auth do
  @moduledoc false
  alias __MODULE__
  alias RR.CLI.Output
  alias RR.Providers.AuthCache
  alias RR.Providers.Rancher
  alias RR.Settings

  @type t :: %Auth{}
  @type error_reason :: :unauthorized | :unknown
  @type error :: {:error, error_reason(), binary()} | {:error, binary()}

  defstruct [:rancher_hostname, :rancher_token]

  def get_auth do
    auth = %Auth{
      rancher_hostname: Settings.get("rancher_hostname"),
      rancher_token: Settings.get("rancher_token")
    }

    if auth.rancher_hostname != nil and auth.rancher_token != nil do
      {:ok, auth}
    else
      {:error, "auth config file incomplete\nto login, run: rr login"}
    end
  end

  def put_auth(auth) do
    Settings.put("rancher_hostname", auth.rancher_hostname)
    Settings.put("rancher_token", auth.rancher_token)
  end

  @spec ensure_valid_auth() :: {:ok, Auth.t()} | error()
  def ensure_valid_auth do
    with {:ok, auth} <- get_auth() do
      check_auth_validity(auth)
    end
  end

  @spec check_auth_validity(Auth.t()) :: {:ok, Auth.t()} | error()
  def check_auth_validity(auth) do
    token_invalid_error_msg =
      "rancher token is invalid has expired. To input a valid token, run the command below\n    rr login"

    with :miss <- cached_auth_result(auth),
         {:ok, token_info} <- Rancher.get_token_info(auth) do
      result = token_valid?(token_info)
      cache_auth_result(auth, result)

      if result do
        {:ok, auth}
      else
        {:error, :unauthorized, token_invalid_error_msg}
      end
    else
      {:hit, true} ->
        {:ok, auth}

      {:hit, false} ->
        {:error, :unauthorized, token_invalid_error_msg}

      {:error, :unauthorized, reason} ->
        cache_auth_result(auth, false)
        {:error, :unauthorized, reason}

      {:error, :unknown, reason} ->
        {:error, :unknown, reason}
    end
  end

  defp token_valid?(token_info) do
    with false <- token_info.expired,
         true <- token_info.enabled do
      {:ok, creation_ts} = DateTime.from_unix(token_info.created_ts, :millisecond)
      expiration_ts = DateTime.add(creation_ts, token_info.ttl, :millisecond)

      if DateTime.before?(DateTime.utc_now(), expiration_ts) do
        if DateTime.diff(expiration_ts, DateTime.utc_now()) < 604_800 do
          Output.error("warning: rancher token will expire in less than 7 days.")
          Output.error("expiration time: #{DateTime.to_string(expiration_ts)}")
          Output.error("To input a valid token, run the command below\n\n    rr login\n")
        end

        true
      else
        false
      end
    else
      _ -> false
    end
  end

  defp cached_auth_result(auth) do
    AuthCache.get(auth_cache_key(auth))
  end

  defp cache_auth_result(auth, result) when is_boolean(result) do
    AuthCache.put(auth_cache_key(auth), result)
  end

  defp auth_cache_key(%Auth{rancher_hostname: hostname, rancher_token: token}) do
    {hostname, token}
  end
end
