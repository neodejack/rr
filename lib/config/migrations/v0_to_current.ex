defmodule RR.Config.Migrations.V0ToCurrent do
  @moduledoc false

  @default_profile "default"
  @profiles_key "profiles"
  @aliases_key "aliases"
  @legacy_aliases_key "alias"
  @hostname_key "rancher_hostname"
  @token_key "rancher_token"

  @spec migrate(map(), non_neg_integer()) :: {:ok, map()} | {:error, String.t()}
  def migrate(raw_config, current_version) when is_map(raw_config) and is_integer(current_version) do
    cond do
      raw_config == %{} ->
        {:ok, current_state(%{}, current_version)}

      Map.has_key?(raw_config, @profiles_key) ->
        migrate_unversioned_profiles(raw_config, current_version)

      legacy_root_keys_present?(raw_config) ->
        migrate_legacy_root_config(raw_config, current_version)

      true ->
        {:error, "legacy config is malformed: expected either a profiles map or root rancher_hostname and rancher_token keys"}
    end
  end

  defp migrate_unversioned_profiles(raw_config, current_version) do
    with profiles when is_map(profiles) <- Map.get(raw_config, @profiles_key),
         {:ok, migrated_profiles} <- normalize_profiles(profiles) do
      {:ok, current_state(migrated_profiles, current_version)}
    else
      {:error, _reason} = error ->
        error

      nil ->
        {:error, "legacy config is malformed: expected profiles to be an object"}

      _ ->
        {:error, "legacy config is malformed: expected profiles to be an object"}
    end
  end

  defp migrate_legacy_root_config(raw_config, current_version) do
    with {:ok, hostname} <- required_string(raw_config, @hostname_key),
         {:ok, token} <- required_string(raw_config, @token_key),
         {:ok, aliases} <- aliases_from_legacy_root(raw_config) do
      {:ok,
       current_state(
         %{
           @default_profile => %{
             @hostname_key => hostname,
             @token_key => token,
             @aliases_key => aliases
           }
         },
         current_version
       )}
    end
  end

  defp current_state(profiles, current_version) do
    %{
      "schema_version" => current_version,
      @profiles_key => profiles
    }
  end

  defp legacy_root_keys_present?(raw_config) do
    Enum.any?([@hostname_key, @token_key, @legacy_aliases_key], &Map.has_key?(raw_config, &1))
  end

  defp normalize_profiles(profiles) do
    Enum.reduce_while(profiles, {:ok, %{}}, fn
      {profile_name, profile}, {:ok, acc} when is_binary(profile_name) ->
        case normalize_profile(profile_name, profile) do
          {:ok, normalized_profile} ->
            {:cont, {:ok, Map.put(acc, profile_name, normalized_profile)}}

          {:error, _reason} = error ->
            {:halt, error}
        end

      {_profile_name, _profile}, _acc ->
        {:halt, {:error, "legacy config is malformed: expected profile names to be strings"}}
    end)
  end

  defp normalize_profile(profile_name, profile) when is_map(profile) do
    with {:ok, hostname} <- string_or_nil(profile, @hostname_key),
         {:ok, token} <- string_or_nil(profile, @token_key),
         {:ok, aliases} <- aliases_from_profile(profile) do
      {:ok,
       %{
         @hostname_key => hostname,
         @token_key => token,
         @aliases_key => aliases
       }}
    else
      {:error, :invalid_aliases} ->
        {:error, "legacy config is malformed: profile '#{profile_name}' has invalid aliases"}

      {:error, reason} ->
        {:error, "legacy config is malformed: profile '#{profile_name}' #{reason}"}
    end
  end

  defp normalize_profile(profile_name, _profile) do
    {:error, "legacy config is malformed: profile '#{profile_name}' must be an object"}
  end

  defp required_string(config, key) do
    case Map.get(config, key) do
      value when is_binary(value) ->
        {:ok, value}

      _value ->
        {:error, "legacy config is malformed: expected rancher_hostname and rancher_token to be strings"}
    end
  end

  defp string_or_nil(config, key) do
    case Map.get(config, key) do
      nil -> {:ok, nil}
      value when is_binary(value) -> {:ok, value}
      _value -> {:error, "has a non-string #{key}"}
    end
  end

  defp aliases_from_profile(profile) do
    profile
    |> Map.get(@aliases_key, %{})
    |> normalize_aliases()
  end

  defp aliases_from_legacy_root(raw_config) do
    raw_config
    |> Map.get(@legacy_aliases_key, %{})
    |> normalize_aliases()
    |> case do
      {:ok, aliases} ->
        {:ok, aliases}

      {:error, _reason} ->
        {:error, "legacy config is malformed: expected alias to be an object mapping alias names to cluster names"}
    end
  end

  defp normalize_aliases(aliases) when is_map(aliases) do
    Enum.reduce_while(aliases, {:ok, %{}}, fn
      {alias_name, cluster_name}, {:ok, acc}
      when is_binary(alias_name) and is_binary(cluster_name) ->
        {:cont, {:ok, Map.put(acc, alias_name, cluster_name)}}

      _entry, _acc ->
        {:halt, {:error, :invalid_aliases}}
    end)
  end

  defp normalize_aliases(_aliases), do: {:error, :invalid_aliases}
end
