defmodule RR.List do
  @moduledoc false
  alias External.RancherHttpClient
  alias RR.Config.Auth
  alias RR.Config.Profiles
  alias RR.Shell

  def run(args) do
    with {:ok, profile_name} <- parse_args(args),
         {:ok, auths} <- resolve_auths(profile_name),
         {:ok, rows} <- fetch_rows(auths) do
      render_table(rows)
      :ok
    end
  end

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, ["the arguments you provided are invalid:\nyou provided: #{Enum.join(invalids, " ")}"]}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      rest != [] ->
        render_help()
        {:error, "the subcommands you provided are invalid\nyou provided: #{Enum.join(rest, " ")}"}

      true ->
        {:ok, Profiles.normalize_profile_name(Keyword.get(switches, :profile))}
    end
  end

  defp args_definition do
    [
      strict: [
        help: :boolean,
        profile: :string
      ],
      aliases: [h: :help, p: :profile]
    ]
  end

  defp render_help do
    Shell.info_stdout("""
    list rancher clusters

    USAGE:
      rr list
      rr list -p <profile>
    """)
  end

  defp resolve_auths(profile_name) when is_binary(profile_name) do
    if Profiles.exists?(profile_name) do
      with {:ok, auth} <- Auth.ensure_valid_auth(profile_name) do
        {:ok, [auth]}
      end
    else
      {:error, "profile '#{profile_name}' not found"}
    end
  end

  defp resolve_auths(nil) do
    case Profiles.names() do
      [] ->
        {:error, "no profiles configured\nto login, run: rr login"}

      profile_names ->
        auths =
          Enum.map(profile_names, fn profile_name ->
            {profile_name, Auth.ensure_valid_auth(profile_name)}
          end)

        errors =
          Enum.flat_map(auths, fn
            {profile_name, {:error, _reason, reason}} -> [{profile_name, reason}]
            {profile_name, {:error, reason}} -> [{profile_name, reason}]
            {_profile_name, {:ok, _auth}} -> []
          end)

        if errors == [] do
          {:ok, Enum.map(auths, fn {_profile_name, {:ok, auth}} -> auth end)}
        else
          {:error, render_profile_errors("failed to validate one or more profiles", errors)}
        end
    end
  end

  defp fetch_rows(auths) do
    results =
      Enum.map(auths, fn auth ->
        {auth.profile_name, RancherHttpClient.get_clusters(auth)}
      end)

    errors =
      Enum.flat_map(results, fn
        {profile_name, {:error, reason}} -> [{profile_name, reason}]
        {_profile_name, {:ok, _clusters}} -> []
      end)

    if errors == [] do
      rows =
        results
        |> Enum.flat_map(fn {profile_name, {:ok, clusters}} ->
          to_rows(profile_name, clusters)
        end)
        |> Enum.sort()

      {:ok, rows}
    else
      {:error, render_profile_errors("failed to load clusters for one or more profiles", errors)}
    end
  end

  defp to_rows(profile_name, clusters) do
    Enum.map(clusters, fn cluster -> {profile_name, cluster["name"], cluster["id"]} end)
  end

  defp render_table([]) do
    Shell.info_stdout("""
    PROFILE  NAME  ID
    -------  ----  --
    no clusters found
    """)
  end

  defp render_table([{_profile_name, _name, _id} | _] = rows) do
    profile_width =
      rows
      |> Enum.map(fn {profile_name, _name, _id} -> String.length(profile_name) end)
      |> Enum.concat([String.length("PROFILE")])
      |> Enum.max()

    name_width =
      rows
      |> Enum.map(fn {_profile_name, name, _id} -> String.length(name) end)
      |> Enum.concat([String.length("NAME")])
      |> Enum.max()

    header =
      "#{String.pad_trailing("PROFILE", profile_width)}  #{String.pad_trailing("NAME", name_width)}  ID"

    separator =
      "#{String.duplicate("-", profile_width)}  #{String.duplicate("-", name_width)}  --"

    lines =
      Enum.map(rows, fn {profile_name, name, id} ->
        "#{String.pad_trailing(profile_name, profile_width)}  #{String.pad_trailing(name, name_width)}  #{id}"
      end)

    Shell.info_stdout(Enum.join([header, separator | lines], "\n"))
  end

  defp render_profile_errors(prefix, errors) do
    details =
      Enum.map_join(errors, "\n", fn {profile_name, reason} ->
        "  #{profile_name}: #{reason}"
      end)

    "#{prefix}:\n#{details}"
  end
end
