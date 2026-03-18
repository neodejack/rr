defmodule RR.Config.Profiles do
  @moduledoc false

  alias RR.Config.Auth

  @default_profile "default"
  @profiles_key "profiles"
  @aliases_key "aliases"
  @legacy_aliases_key "alias"
  @hostname_key "rancher_hostname"
  @token_key "rancher_token"

  @spec state() :: map()
  def state do
    raw_state = External.Config.read()
    normalized_state = normalize_state(raw_state)

    if raw_state != normalized_state do
      External.Config.write(normalized_state)
    end

    normalized_state
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
      updated_profile =
        put_in(profile, [@aliases_key, alias_name], cluster_name)

      state()
      |> put_in([@profiles_key, profile_name], updated_profile)
      |> External.Config.write()
    end
  end

  @spec resolve_alias(String.t()) ::
          :miss
          | {:ok, %{profile_name: String.t(), cluster_name: String.t()}}
          | {:error, :ambiguous, [%{profile_name: String.t(), cluster_name: String.t()}]}
  def resolve_alias(alias_name) when is_binary(alias_name) do
    matches =
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

    case matches do
      [] -> :miss
      [match] -> {:ok, match}
      _ -> {:error, :ambiguous, matches}
    end
  end

  defp profiles(state) do
    Map.get(state, @profiles_key, %{})
  end

  defp normalize_state(raw_state) when is_map(raw_state) do
    %{@profiles_key => normalize_profiles(raw_state)}
  end

  defp normalize_state(_raw_state), do: %{@profiles_key => %{}}

  defp normalize_profiles(%{@profiles_key => profiles}) when is_map(profiles) do
    Map.new(profiles, fn {profile_name, profile} ->
      {profile_name, normalize_profile(profile)}
    end)
  end

  defp normalize_profiles(raw_state) do
    legacy_profile = normalize_legacy_profile(raw_state)

    case legacy_profile do
      nil -> %{}
      profile -> %{@default_profile => profile}
    end
  end

  defp normalize_legacy_profile(raw_state) do
    hostname = Map.get(raw_state, @hostname_key)
    token = Map.get(raw_state, @token_key)
    aliases = normalize_aliases(Map.get(raw_state, @legacy_aliases_key))

    if is_nil(hostname) and is_nil(token) and aliases == %{} do
      nil
    else
      %{
        @hostname_key => hostname,
        @token_key => token,
        @aliases_key => aliases
      }
    end
  end

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
