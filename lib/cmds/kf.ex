defmodule RR.KubeConfig do
  @moduledoc false
  alias External.RancherHttpClient
  alias RR.Alias
  alias RR.Config
  alias RR.Shell

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :kubeconfig]

  def run(args) do
    with {:ok, {switches, cluster_name_substring}} <- parse_args(args) do
      cluster_name_substring = Alias.resolve(cluster_name_substring)

      with {:ok, clusters} <- RancherHttpClient.get_clusters(),
           {:ok, target_cluster} <- clusters |> parse_cluster() |> select_cluster(cluster_name_substring),
           {:ok, kubconfig_path} <- ensure_valid_kubeconfig(target_cluster, Keyword.get(switches, :new, false)) do
        output_kubeconfig_path(kubconfig_path, Keyword.get(switches, :sh, false))
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
        new: :boolean
      ],
      alias: [h: :help]
    ]
  end

  defp render_help do
    Shell.info("""
    obtain and manage kubeconfigs from rancher

    USAGE:
      rr kf <cluster_name_substring> [flags]

      rr trys to match <cluster_name_substring> as substring of the cluster names, and will only proceed if there's one exact match.
      no match or more than one match will lead to error.
      
    FlAGS:
      --new Overwrite existing valid kubeconfigs.
      --sh Generate `export KUBECONIFG=` shell command to use a kubeconfig in the current shell.
    """)
  end

  defp ensure_valid_kubeconfig(kubeconfig, overwrite_existing_kf)

  defp ensure_valid_kubeconfig(kubeconfig, false) do
    if kf_valid?(kubeconfig) do
      Shell.info_stderr("found existing valid kubeconifg: #{kubeconfig_file_path(kubeconfig)}")

      {:ok, kubeconfig_file_path(kubeconfig)}
    else
      kubeconfig
      |> RancherHttpClient.get_kubeconfig()
      |> save_to_file()
    end
  end

  defp ensure_valid_kubeconfig(kubeconfig, true) do
    Shell.info_stderr("overwriting existing valid kubeconfig: #{kubeconfig_file_path(kubeconfig)}")

    kubeconfig
    |> RancherHttpClient.get_kubeconfig()
    |> save_to_file()
  end

  defp output_kubeconfig_path(kubeconfig_path, generate_sh_template?)

  defp output_kubeconfig_path(kubconfig_path, true) do
    sh_template_path()
    |> EEx.eval_file(kf_path: kubconfig_path)
    |> Shell.info()
  end

  defp output_kubeconfig_path(kubconfig_path, false) do
    Shell.info(kubconfig_path)
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
    with :ok <- File.mkdir_p(kubeconfig_dir()),
         kb_path = kubeconfig_file_path(target_cluster),
         :ok <- File.write(kb_path, target_cluster.kubeconfig) do
      Shell.info_stderr(["new kubeconfig is saved to ", kb_path])
      {:ok, kb_path}
    else
      {:error, err} -> {:error, ["error when saving kubeconfig:\n", err]}
    end
  end

  defp save_to_file({:error, _} = error), do: error

  defp parse_cluster(raw_clusters) when is_list(raw_clusters) and [] != raw_clusters do
    Enum.map(raw_clusters, &%__MODULE__{id: &1["id"], name: &1["name"]})
  end

  defp select_cluster(clusters, cluster_name_substring) do
    case Enum.filter(clusters, &String.contains?(&1.name, cluster_name_substring)) do
      [] ->
        {:error, "no match were found for the cluster name '#{cluster_name_substring}'"}

      [cluster] ->
        {:ok, cluster}

      [_ | _] = matched_clusters ->
        {:error,
         [
           "more than one matches were found for the cluster name '#{cluster_name_substring}'\nthese matches are found:\n",
           Enum.map(matched_clusters, &[" ", &1.name, "\n"]),
           "please make your cluster name more precise so that there will only be one single match"
         ]}
    end
  end

  defp kubeconfig_dir do
    Path.join(Config.home_dir(), "kubeconfigs")
  end

  defp kubeconfig_file_path(%__MODULE__{name: name}) do
    Path.join(
      kubeconfig_dir(),
      name
    )
  end

  defp sh_template_path do
    :rr
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates/sh.eex")
  end
end
