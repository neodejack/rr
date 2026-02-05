defmodule RR.Config.Auth do
  @moduledoc false
  alias RR.Config
  alias RR.Shell

  @auth_cache_table :rr_auth_cache

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
    with {:ok, auth} <- get_auth() do
      case cached_auth_result(auth) do
        {:ok, _auth} = ok ->
          ok

        {:error, _reason} = error ->
          error

        :miss ->
          with {:ok, token_info} <- External.RancherHttpClient.get_token_info(auth),
               result <- ensure_token_info_valid(token_info) do
            cache_auth_result(auth, result)

            case result do
              {:ok, _token_description} -> {:ok, auth}
              {:error, reason} -> {:error, reason}
            end
          else
            {:error, reason} ->
              cache_auth_result(auth, {:error, reason})
              {:error, reason}
          end
      end
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

  defp cached_auth_result(auth) do
    ensure_auth_cache_table()

    case :ets.lookup(@auth_cache_table, auth_cache_key(auth)) do
      [{_key, {:ok, :valid}}] -> {:ok, auth}
      [{_key, {:error, reason}}] -> {:error, reason}
      _ -> :miss
    end
  end

  defp cache_auth_result(auth, {:ok, _token_description}) do
    ensure_auth_cache_table()
    :ets.insert(@auth_cache_table, {auth_cache_key(auth), {:ok, :valid}})
    :ok
  end

  defp cache_auth_result(auth, {:error, reason}) do
    ensure_auth_cache_table()
    :ets.insert(@auth_cache_table, {auth_cache_key(auth), {:error, reason}})
    :ok
  end

  defp auth_cache_key(%__MODULE__{rancher_hostname: hostname, rancher_token: token}) do
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
