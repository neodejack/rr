defmodule RR.Alias do
  @moduledoc false
  alias External.RancherHttpClient
  alias RR.Config.Auth
  alias RR.Config.Profiles
  alias RR.Shell

  def run(args) do
    with {:ok, command} <- parse_args(args) do
      execute(command)
    end
  end

  def resolve(alias_name, profile_name \\ nil)

  def resolve(alias_name, profile_name) when is_binary(profile_name) do
    case Map.fetch(Profiles.aliases(profile_name), alias_name) do
      {:ok, cluster_name} ->
        {:ok, %{profile_name: profile_name, cluster_name: cluster_name}}

      :error ->
        :miss
    end
  end

  def resolve(alias_name, nil) do
    Profiles.resolve_alias(alias_name)
  end

  defp execute({:list}) do
    render_alias_list()
  end

  defp execute({:set, profile_name}) do
    with {:ok, profile_name} <- select_profile_name(profile_name),
         {:ok, alias_name} <- prompt_alias_name(),
         {:ok, existing_alias} <- ensure_alias_available(profile_name, alias_name),
         {:ok, auth} <- Auth.ensure_valid_auth(profile_name),
         {:ok, cluster_name} <- select_cluster_name(auth) do
      case maybe_confirm_overwrite(alias_name, existing_alias, cluster_name) do
        :ok ->
          with :ok <- persist_alias(profile_name, alias_name, cluster_name) do
            Shell.info_stdout("profile '#{profile_name}': alias #{alias_name} -> #{cluster_name}")
            :ok
          end

        :abort ->
          :ok
      end
    end
  end

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, ["the arguments you provided are invalid:", invalids]}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      Keyword.has_key?(switches, :list) ->
        {:ok, {:list}}

      rest == [] ->
        {:ok, {:set, normalize_profile_name(Keyword.get(switches, :profile))}}

      true ->
        render_help()
        {:error, "rr alias command doesn't take positional arguments"}
    end
  end

  defp args_definition do
    [
      strict: [
        help: :boolean,
        list: :boolean,
        profile: :string
      ],
      aliases: [h: :help, p: :profile]
    ]
  end

  defp render_alias_list do
    grouped_aliases =
      Profiles.aliases_by_profile()
      |> Enum.sort_by(fn {profile_name, _aliases} -> profile_name end)
      |> Enum.reject(fn {_profile_name, aliases} -> aliases == %{} end)

    if grouped_aliases == [] do
      Shell.info_stdout("no aliases set")
    else
      Shell.info_stdout("these aliases are found:\n")

      grouped_aliases
      |> Enum.map_join("\n", fn {profile_name, aliases} ->
        entries =
          aliases
          |> Enum.sort()
          |> Enum.map_join("\n", fn {alias_name, full_name} ->
            "  #{alias_name} -> #{full_name}"
          end)

        "#{profile_name}\n#{entries}"
      end)
      |> Shell.info_stdout()
    end

    :ok
  end

  defp render_help do
    Shell.info_stdout("""

    create or inspect profile-scoped cluster aliases

    USAGE:
      rr alias
      rr alias -p <profile>
      rr alias --list

    FLAGS:
      --list List all the aliases currently set
      -p, --profile Target a specific profile
    """)
  end

  defp select_profile_name(profile_name) when is_binary(profile_name) do
    if Profiles.exists?(profile_name) do
      {:ok, profile_name}
    else
      {:error, "profile '#{profile_name}' not found"}
    end
  end

  defp select_profile_name(nil) do
    case Profiles.names() do
      [] ->
        {:error, "no profiles configured\nto login, run: rr login"}

      profile_names ->
        {:ok, Owl.IO.select(profile_names, label: "select profile")}
    end
  end

  defp normalize_profile_name(nil), do: nil

  defp normalize_profile_name(profile_name) do
    profile_name
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp prompt_alias_name do
    alias_name =
      [label: "alias text"]
      |> Owl.IO.input()
      |> String.trim()

    case alias_name do
      "" ->
        Shell.error("alias text cannot be blank")
        prompt_alias_name()

      _ ->
        {:ok, alias_name}
    end
  end

  defp ensure_alias_available(profile_name, alias_name) do
    case Profiles.resolve_alias(alias_name) do
      :miss ->
        {:ok, nil}

      {:ok, %{profile_name: ^profile_name} = existing_alias} ->
        {:ok, existing_alias}

      {:ok, %{profile_name: owner_profile_name, cluster_name: owner_cluster_name}} ->
        {:error,
         "alias '#{alias_name}' is already claimed by profile '#{owner_profile_name}' for cluster '#{owner_cluster_name}'"}
    end
  end

  defp select_cluster_name(auth) do
    with {:ok, clusters} <- RancherHttpClient.get_clusters(auth) do
      cluster_names =
        clusters
        |> Enum.map(& &1["name"])
        |> Enum.reject(&is_nil/1)
        |> Enum.sort()

      case cluster_names do
        [] ->
          {:error, "no clusters found for profile '#{auth.profile_name}'"}

        _ ->
          {:ok, Owl.IO.select(cluster_names, label: "select cluster")}
      end
    end
  end

  defp maybe_confirm_overwrite(_alias_name, nil, _cluster_name), do: :ok

  defp maybe_confirm_overwrite(alias_name, %{cluster_name: current_cluster_name}, cluster_name) do
    if Owl.IO.confirm(
         message: [
           "alias '#{alias_name}' already points to '#{current_cluster_name}'",
           "overwrite it with '#{cluster_name}'?"
         ]
       ) do
      :ok
    else
      :abort
    end
  end

  defp persist_alias(profile_name, alias_name, cluster_name) do
    case Profiles.put_alias(profile_name, alias_name, cluster_name) do
      :ok ->
        :ok

      {:error, :alias_owned_by_other_profile, %{profile_name: owner_profile_name, cluster_name: owner_cluster_name}} ->
        {:error,
         "alias '#{alias_name}' is already claimed by profile '#{owner_profile_name}' for cluster '#{owner_cluster_name}'"}

      {:error, _reason} = error ->
        error
    end
  end
end
