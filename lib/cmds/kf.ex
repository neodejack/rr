defmodule RR.KubeConfig do
  @moduledoc false
  alias External.RancherHttpClient
  alias RR.Alias
  alias RR.Config
  alias RR.Config.Auth
  alias RR.Config.Profiles
  alias RR.Shell

  @enforce_keys [:profile_name, :id, :name]
  defstruct [:profile_name, :id, :name, :kubeconfig]

  def run(args) do
    with {:ok, {switches, cluster_name_substring}} <- parse_args(args),
         profile_name = Profiles.normalize_profile_name(Keyword.get(switches, :profile)),
         {:ok, auth, target_cluster} <- resolve_target_cluster(profile_name, cluster_name_substring),
         {:ok, kubconfig_path} <-
           ensure_valid_kubeconfig(auth, target_cluster, Keyword.get(switches, :new, false)) do
      output_kubeconfig_path(kubconfig_path, Keyword.get(switches, :sh, false))
      :ok
    end
  end

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, ["the arguments you provided are invalid: ", invalids]}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      rest == [] ->
        render_help()
        {:error, "you didn't provide <cluster_name_substring>"}

      match?([_], rest) ->
        [cluster] = rest
        {:ok, {switches, cluster}}

      true ->
        render_help()
        {:error, ["you provided more than one clusters: ", Enum.intersperse(rest, ", ")]}
    end
  end

  defp args_definition do
    [
      strict: [
        help: :boolean,
        sh: :boolean,
        new: :boolean,
        profile: :string
      ],
      aliases: [h: :help, p: :profile]
    ]
  end

  defp render_help do
    Shell.info_stdout("""
    obtain and manage kubeconfigs from rancher

    USAGE:
      rr kf <cluster_name_substring> [flags]
      rr kf -p <profile> <cluster_name_substring> [flags]

      rr trys to match <cluster_name_substring> as substring of the cluster names, and will only proceed if there's one exact match.
      no match or more than one match will lead to error.

    FLAGS:
      --new Overwrite existing valid kubeconfigs.
      --sh Generate `export KUBECONFIG=` shell command to use a kubeconfig in the current shell.
      -p, --profile Target a specific profile
    """)
  end

  defp ensure_valid_kubeconfig(auth, kubeconfig, overwrite_existing_kf)

  defp ensure_valid_kubeconfig(auth, kubeconfig, false) do
    if kf_valid?(kubeconfig) do
      Shell.info_stderr("found existing valid kubeconifg: #{kubeconfig_file_path(kubeconfig)}")

      {:ok, kubeconfig_file_path(kubeconfig)}
    else
      kubeconfig
      |> then(&RancherHttpClient.get_kubeconfig(auth, &1))
      |> save_to_file()
    end
  end

  defp ensure_valid_kubeconfig(auth, kubeconfig, true) do
    Shell.info_stderr("overwriting existing valid kubeconfig: #{kubeconfig_file_path(kubeconfig)}")

    kubeconfig
    |> then(&RancherHttpClient.get_kubeconfig(auth, &1))
    |> save_to_file()
  end

  defp output_kubeconfig_path(kubeconfig_path, generate_sh_template?)

  defp output_kubeconfig_path(kubconfig_path, true) do
    sh_template_path()
    |> EEx.eval_file(kf_path: kubconfig_path)
    |> Shell.info_stdout()
  end

  defp output_kubeconfig_path(kubconfig_path, false) do
    Shell.info_stdout(kubconfig_path)
  end

  defp kf_valid?(kubeconifg) do
    path = kubeconfig_file_path(kubeconifg)

    if File.exists?(path) do
      case System.cmd("kubectl", ["get", "pods", "--kubeconfig=#{path}"], stderr_to_stdout: true) do
        {_, 0} -> true
        {_, 1} -> false
      end
    end
  end

  defp save_to_file({:ok, target_cluster}) do
    kb_path = kubeconfig_file_path(target_cluster)

    with :ok <- File.mkdir_p(Path.dirname(kb_path)),
         :ok <- File.write(kb_path, target_cluster.kubeconfig) do
      Shell.info_stderr(["new kubeconfig is saved to ", kb_path])
      {:ok, kb_path}
    else
      {:error, err} -> {:error, ["error when saving kubeconfig:\n", err]}
    end
  end

  defp save_to_file({:error, _} = error), do: error

  defp parse_cluster(profile_name, raw_clusters) when is_list(raw_clusters) do
    Enum.map(raw_clusters, &%__MODULE__{profile_name: profile_name, id: &1["id"], name: &1["name"]})
  end

  defp select_cluster(clusters, cluster_name_substring) do
    case Enum.filter(clusters, &String.contains?(&1.name, cluster_name_substring)) do
      [] ->
        {:error, "no match were found for the cluster name '#{cluster_name_substring}' in any profile"}

      [cluster] ->
        {:ok, cluster}

      [_ | _] = matched_clusters ->
        {:error,
         render_cluster_ambiguity_options(
           cluster_name_substring,
           Enum.map(matched_clusters, &%{profile_name: &1.profile_name, cluster_name: &1.name})
         )}
    end
  end

  defp kubeconfig_dir(profile_name) do
    Path.join([Config.home_dir(), "kubeconfigs", profile_name])
  end

  defp kubeconfig_file_path(%__MODULE__{profile_name: profile_name, name: name}) do
    Path.join(kubeconfig_dir(profile_name), name)
  end

  defp sh_template_path do
    :rr
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates/sh.eex")
  end

  defp resolve_target_cluster(profile_name, cluster_name_substring) when is_binary(profile_name) do
    if Profiles.exists?(profile_name) do
      with {:ok, auth} <- Auth.ensure_valid_auth(profile_name),
           cluster_name = resolve_alias_in_profile(cluster_name_substring, profile_name),
           {:ok, clusters} <- RancherHttpClient.get_clusters(auth),
           {:ok, target_cluster} <- profile_name |> parse_cluster(clusters) |> select_cluster(cluster_name) do
        {:ok, auth, target_cluster}
      end
    else
      {:error, "profile '#{profile_name}' not found"}
    end
  end

  defp resolve_target_cluster(nil, cluster_name_substring) do
    case Alias.resolve(cluster_name_substring) do
      {:ok, %{profile_name: profile_name, cluster_name: cluster_name}} ->
        Shell.info_stderr("resolving alias in profile '#{profile_name}': #{cluster_name_substring} -> #{cluster_name}")

        resolve_target_cluster(profile_name, cluster_name)

      :miss ->
        with {:ok, auths} <- Auth.all_auths(),
             {:ok, clusters} <- fetch_clusters_for_auths(auths),
             {:ok, target_cluster} <- select_cluster(clusters, cluster_name_substring),
             {:ok, auth} <- auth_for_profile(auths, target_cluster.profile_name) do
          {:ok, auth, target_cluster}
        end
    end
  end

  defp resolve_alias_in_profile(cluster_name_substring, profile_name) do
    case Alias.resolve(cluster_name_substring, profile_name) do
      {:ok, %{cluster_name: cluster_name}} ->
        Shell.info_stderr("resolving alias in profile '#{profile_name}': #{cluster_name_substring} -> #{cluster_name}")

        cluster_name

      :miss ->
        cluster_name_substring
    end
  end

  defp fetch_clusters_for_auths(auths) do
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
      {:ok,
       Enum.flat_map(results, fn {profile_name, {:ok, clusters}} ->
         parse_cluster(profile_name, clusters)
       end)}
    else
      {:error, render_profile_errors("failed to load clusters for one or more profiles", errors)}
    end
  end

  defp auth_for_profile(auths, profile_name) do
    case Enum.find(auths, &(&1.profile_name == profile_name)) do
      nil -> {:error, "profile '#{profile_name}' not found"}
      auth -> {:ok, auth}
    end
  end

  defp render_cluster_ambiguity_options(cluster_name_substring, matches) do
    details =
      matches
      |> Enum.sort_by(fn %{profile_name: profile_name, cluster_name: cluster_name} ->
        {profile_name, cluster_name}
      end)
      |> Enum.map_join("", fn %{profile_name: profile_name, cluster_name: cluster_name} ->
        "  #{profile_name} -> #{cluster_name}\n"
      end)

    "more than one matches were found for the cluster name '#{cluster_name_substring}'\n" <>
      "these matches are found:\n" <>
      details <>
      "you have three options:\n" <>
      "1. to select a certain profile, use -p\n" <>
      "2. be more specific on the name\n" <>
      "3. use rr alias"
  end

  defp render_profile_errors(prefix, errors) do
    details =
      Enum.map_join(errors, "\n", fn {profile_name, reason} ->
        "  #{profile_name}: #{reason}"
      end)

    "#{prefix}:\n#{details}"
  end
end
