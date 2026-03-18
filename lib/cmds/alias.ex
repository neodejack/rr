defmodule RR.Alias do
  @moduledoc false
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

  defp execute({:set, profile_name, alias_name, full_name}) do
    with {:ok, profile_name} <- select_profile_name(profile_name),
         :ok <- Profiles.put_alias(profile_name, alias_name, full_name) do
      Shell.info_stdout("profile '#{profile_name}': alias #{alias_name} -> #{full_name}")
      :ok
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

      match?([_, _], rest) ->
        [alias_name, full_name] = rest
        {:ok, {:set, normalize_profile_name(Keyword.get(switches, :profile)), alias_name, full_name}}

      true ->
        render_help()
        {:error, "you didn't provide valid <cluster_alias> and <cluster_full_name>"}
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

    `rr alias` set alias.
    alias will be substituted when used in `rr kf <alias>

    USAGE:
      rr alias <cluster_alias> <cluster_full_name>
      rr alias -p <profile> <cluster_alias> <cluster_full_name>
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
end
