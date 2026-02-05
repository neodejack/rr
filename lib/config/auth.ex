defmodule RR.Config.Auth do
  @moduledoc false
  alias __MODULE__
  alias RR.Config
  alias RR.Shell

  @auth_cache_table :rr_auth_cache

  @type t :: %Auth{}

  defstruct [:rancher_hostname, :rancher_token]

  def get_auth do
    auth = %Auth{
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

  @spec ensure_valid_auth() :: {:ok, Auth.t()} | {:error, binary()}
  def ensure_valid_auth do
    with {:ok, auth} <- get_auth() do
      check_auth_validity_from_ets_or_rancher(auth)
    end
  end

  @spec check_auth_validity_from_ets_or_rancher(Auth.t()) :: {:ok, Auth.t()} | {:error, binary()}
  def check_auth_validity_from_ets_or_rancher(auth) do
    token_expired_error_msg = "rancher token has expired. To input a valid token, run the command below\n    rr login"

    with :miss <- cached_auth_result(auth),
         {:ok, token_info} <- External.RancherHttpClient.get_token_info(auth) do
      result = token_valid?(token_info)
      cache_auth_result(auth, result)

      if result do
        {:ok, auth}
      else
        {:error, token_expired_error_msg}
      end
    else
      {:hit, true} ->
        {:ok, auth}

      {:hit, false} ->
        {:error, token_expired_error_msg}

      {:error, reason} ->
        cache_auth_result(auth, false)
        {:error, reason}
    end
  end

  defp token_valid?(token_info) do
    with false <- token_info.expired,
         true <- token_info.enabled do
      creation_ts = DateTime.from_unix!(token_info.created_ts, :millisecond)
      expiration_ts = DateTime.add(creation_ts, token_info.ttl, :millisecond)

      if DateTime.before?(DateTime.utc_now(), expiration_ts) do
        if DateTime.diff(expiration_ts, DateTime.utc_now()) < 604_800 do
          Shell.error(
            "warning: rancher token will expire in less than 7 days. To input a valid token, run the command below\n    rr login"
          )

          Shell.error("expiration time: #{DateTime.to_string(expiration_ts)}")
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
    ensure_auth_cache_table()

    case :ets.lookup(@auth_cache_table, auth_cache_key(auth)) do
      [{_key, valid?}] when is_boolean(valid?) -> {:hit, valid?}
      _ -> :miss
    end
  end

  defp cache_auth_result(auth, result) when is_boolean(result) do
    ensure_auth_cache_table()
    :ets.insert(@auth_cache_table, {auth_cache_key(auth), result})
    :ok
  end

  defp auth_cache_key(%Auth{rancher_hostname: hostname, rancher_token: token}) do
    {hostname, token}
  end

  defp ensure_auth_cache_table do
    case :ets.whereis(@auth_cache_table) do
      :undefined ->
        try do
          :ets.new(@auth_cache_table, [:named_table, :set, :public, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end

    :ok
  end
end
