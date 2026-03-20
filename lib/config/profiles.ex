defmodule RR.Config.Profiles do
  @moduledoc false

  alias RR.Config.Auth
  alias RR.Config.Schema

  @schema_version_key "schema_version"
  @profiles_key "profiles"
  @aliases_key "aliases"
  @hostname_key "rancher_hostname"
  @token_key "rancher_token"

  @spec state() :: map()
  def state do
    normalize_state(External.Config.read())
  end

  @spec names() :: [String.t()]
  def names do
    state()
    |> profiles()
    |> Map.keys()
    |> Enum.sort()
  end

  @spec get(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get(profile_name) when is_binary(profile_name) do
    case Kernel.get_in(state(), [@profiles_key, profile_name]) do
      nil -> {:error, "profile '#{profile_name}' not found"}
      profile -> {:ok, profile}
    end
  end

  @spec put(String.t(), Auth.t()) :: :ok | {:error, term()}
  def put(profile_name, %Auth{} = auth) when is_binary(profile_name) do
    profile =
      case get(profile_name) do
        {:ok, existing_profile} -> existing_profile
        {:error, _reason} -> default_profile()
      end

    updated_profile =
      profile
      |> Map.put(@hostname_key, auth.rancher_hostname)
      |> Map.put(@token_key, auth.rancher_token)
      |> Map.put(@aliases_key, normalize_aliases(profile[@aliases_key]))

    state()
    |> put_in([@profiles_key, profile_name], updated_profile)
    |> External.Config.write()
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(profile_name) when is_binary(profile_name) do
    match?({:ok, _profile}, get(profile_name))
  end

  @spec aliases(String.t()) :: map()
  def aliases(profile_name) when is_binary(profile_name) do
    case get(profile_name) do
      {:ok, profile} -> normalize_aliases(profile[@aliases_key])
      {:error, _reason} -> %{}
    end
  end

  @spec aliases_by_profile() :: %{String.t() => map()}
  def aliases_by_profile do
    state()
    |> profiles()
    |> Map.new(fn {profile_name, profile} ->
      {profile_name, normalize_aliases(profile[@aliases_key])}
    end)
  end

  @spec put_alias(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def put_alias(profile_name, alias_name, cluster_name)
      when is_binary(profile_name) and is_binary(alias_name) and is_binary(cluster_name) do
    with {:ok, profile} <- get(profile_name) do
      case alias_matches(alias_name) do
        [] ->
          write_alias(state(), profile_name, profile, alias_name, cluster_name)

        [%{profile_name: ^profile_name}] ->
          write_alias(state(), profile_name, profile, alias_name, cluster_name)

        [%{profile_name: owner_profile_name, cluster_name: owner_cluster_name}] ->
          {:error, :alias_owned_by_other_profile, %{profile_name: owner_profile_name, cluster_name: owner_cluster_name}}

        matches ->
          {:error, :duplicate_aliases, matches}
      end
    end
  end

  @spec resolve_alias(String.t()) ::
          :miss
          | {:ok, %{profile_name: String.t(), cluster_name: String.t()}}
  def resolve_alias(alias_name) when is_binary(alias_name) do
    case alias_matches(alias_name) do
      [] -> :miss
      [match] -> {:ok, match}
      matches -> raise ArgumentError, duplicate_alias_error(alias_name, matches)
    end
  end

  defp alias_matches(alias_name) do
    aliases_by_profile()
    |> Enum.sort_by(fn {profile_name, _aliases} -> profile_name end)
    |> Enum.flat_map(fn {profile_name, profile_aliases} ->
      case Map.fetch(profile_aliases, alias_name) do
        {:ok, cluster_name} ->
          [%{profile_name: profile_name, cluster_name: cluster_name}]

        :error ->
          []
      end
    end)
  end

  defp write_alias(state, profile_name, profile, alias_name, cluster_name) do
    updated_profile =
      put_in(profile, [@aliases_key, alias_name], cluster_name)

    state
    |> put_in([@profiles_key, profile_name], updated_profile)
    |> External.Config.write()
  end

  defp duplicate_alias_error(alias_name, matches) do
    details =
      matches
      |> Enum.sort_by(fn %{profile_name: profile_name, cluster_name: cluster_name} ->
        {profile_name, cluster_name}
      end)
      |> Enum.map_join("\n", fn %{profile_name: profile_name, cluster_name: cluster_name} ->
        "  #{profile_name} -> #{cluster_name}"
      end)

    "alias '#{alias_name}' exists more than once in local config:\n" <>
      details <>
      "\nplease remove the duplicate alias entries before retrying"
  end

  defp profiles(state) do
    Map.get(state, @profiles_key, %{})
  end

  defp normalize_state(%{@schema_version_key => version} = raw_state) do
    if version == Schema.current_version() do
      %{
        @schema_version_key => Schema.current_version(),
        @profiles_key => normalize_profiles(Map.get(raw_state, @profiles_key))
      }
    else
      Schema.empty_state()
    end
  end

  defp normalize_state(_raw_state), do: Schema.empty_state()

  defp normalize_profiles(profiles) when is_map(profiles) do
    Map.new(profiles, fn {profile_name, profile} ->
      {profile_name, normalize_profile(profile)}
    end)
  end

  defp normalize_profiles(_profiles), do: %{}

  defp normalize_profile(profile) when is_map(profile) do
    %{
      @hostname_key => Map.get(profile, @hostname_key),
      @token_key => Map.get(profile, @token_key),
      @aliases_key => normalize_aliases(Map.get(profile, @aliases_key))
    }
  end

  defp normalize_profile(_profile), do: default_profile()

  defp normalize_aliases(aliases) when is_map(aliases), do: aliases
  defp normalize_aliases(_aliases), do: %{}

  defp default_profile do
    %{
      @hostname_key => nil,
      @token_key => nil,
      @aliases_key => %{}
    }
  end
end
