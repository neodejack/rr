defmodule RR.Config.Auth do
  @moduledoc false
  alias __MODULE__
  alias RR.Config.Profiles
  alias RR.Shell

  @auth_cache_table :rr_auth_cache

  @type t :: %Auth{}

  defstruct [:profile_name, :rancher_hostname, :rancher_token]

  def get_auth(profile_name) when is_binary(profile_name) do
    with {:ok, profile} <- Profiles.get(profile_name) do
      auth = %Auth{
        profile_name: profile_name,
        rancher_hostname: profile["rancher_hostname"],
        rancher_token: profile["rancher_token"]
      }

      if auth.rancher_hostname != nil and auth.rancher_token != nil do
        {:ok, auth}
      else
        {:error,
         "auth config file incomplete for profile '#{profile_name}'\nto login, run: #{login_command(profile_name)}"}
      end
    end
  end

  def put_auth(profile_name, %Auth{} = auth) when is_binary(profile_name) do
    Profiles.put(profile_name, %{auth | profile_name: profile_name})
  end

  @type error_reason :: :unauthorized | :unknown
  @type error :: {:error, error_reason(), binary()} | {:error, binary()}

  @spec ensure_valid_auth(String.t()) :: {:ok, Auth.t()} | error()
  def ensure_valid_auth(profile_name) when is_binary(profile_name) do
    with {:ok, auth} <- get_auth(profile_name) do
      check_auth_validity_from_ets_or_rancher(auth)
    end
  end

  @spec all_auths() :: [Auth.t()]
  def all_auths do
    Enum.flat_map(Profiles.names(), fn profile_name ->
      case get_auth(profile_name) do
        {:ok, auth} -> [auth]
        {:error, _reason} -> []
      end
    end)
  end

  @spec check_auth_validity_from_ets_or_rancher(Auth.t()) :: {:ok, Auth.t()} | error()
  def check_auth_validity_from_ets_or_rancher(auth) do
    token_invalid_error_msg =
      "rancher token is invalid has expired. To input a valid token, run the command below\n    #{login_command(auth.profile_name || "default")}"

    with :miss <- cached_auth_result(auth),
         {:ok, token_info} <- External.RancherHttpClient.get_token_info(auth) do
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
          Shell.error("warning: rancher token will expire in less than 7 days.")

          Shell.error("expiration time: #{DateTime.to_string(expiration_ts)}")

          Shell.error("To input a valid token, run the command below\n\n    rr login\n")
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

  defp auth_cache_key(%Auth{profile_name: profile_name, rancher_hostname: hostname, rancher_token: token}) do
    {profile_name, hostname, token}
  end

  defp login_command("default"), do: "rr login"
  defp login_command(profile_name), do: "rr login -p #{profile_name}"

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
