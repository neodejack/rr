defmodule RR.KubeConfig do
  alias RR.Alias
  alias RR.Shell
  alias RR.Config
  alias External.RancherHttpClient
  require Logger

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :kubeconfig]

  def run(args) do
    {switches, cluster_name_substring} = parse_args!(args)

    cluster_name_substring = Alias.resolve(cluster_name_substring)

    {:ok, target_cluster} =
      with {:ok, clusters} <- RancherHttpClient.get_clusters() do
        clusters
        |> parse_cluster()
        |> select_cluster(cluster_name_substring)
      else
        {:error, err_msg} -> Shell.raise(err_msg)
      end

    # TODO:§refactor_kf 
    execute(
      target_cluster,
      kf_valid?(target_cluster),
      Keyword.get(switches, :new, false),
      Keyword.get(switches, :sh, false)
    )
  end

  def parse_args!(args) do
    with {switches, _, _} = args <- OptionParser.parse(args, args_definition()),
         false <- Keyword.has_key?(switches, :help) do
      case args do
        {switches, [cluster], []} ->
          {switches, cluster}

        {_switches, [_cluster], invalid_args} ->
          invalids = invalid_args |> Enum.map(fn {arg, _value} -> arg end)

          Shell.error([
            "the arguments you provided are invalid: ",
            invalids
          ])

          render_help()

        {_switches, [], _} ->
          render_help()

        {_switches, [_ | _] = clusters, _} ->
          Shell.raise([
            "you provided more than one clusters: ",
            Enum.intersperse(clusters, ", ")
          ])

          render_help()
      end
    else
      true -> render_help()
    end
  end

  def args_definition() do
    [
      strict: [
        help: :boolean,
        sh: :boolean,
        new: :boolean
      ],
      alias: [h: :help]
    ]
  end

  def render_help() do
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

    System.halt(0)
  end

  def execute(kubeconfig, existing_kf_valid?, overwrite_existing_kf, generate_sh_template?)

  def execute(kubeconifg, false, _, true) do
    kubeconifg
    |> RancherHttpClient.get_kubeconfig!()
    |> save_to_file!()

    sh_template_path()
    |> EEx.eval_file(kf_path: kubeconfig_file_path(kubeconifg))
    |> Shell.info()
  end

  def execute(kubeconifg, false, _overwrite_existing_kf, false) do
    kubeconifg
    |> RancherHttpClient.get_kubeconfig!()
    |> save_to_file!()
    |> Shell.info()
  end

  def execute(kubeconifg, true, false, true) do
    Shell.info_stderr("found existing valid kubeconifg: #{kubeconfig_file_path(kubeconifg)}")

    sh_template_path()
    |> EEx.eval_file(kf_path: kubeconfig_file_path(kubeconifg))
    |> Shell.info()
  end

  def execute(kubeconifg, true, false, false) do
    Shell.info_stderr("found existing valid kubeconifg: #{kubeconfig_file_path(kubeconifg)}")

    kubeconifg
    |> kubeconfig_file_path()
    |> Shell.info()
  end

  def execute(kubeconifg, true, true, true) do
    kubeconifg
    |> RancherHttpClient.get_kubeconfig!()
    |> save_to_file!()

    sh_template_path()
    |> EEx.eval_file(kf_path: kubeconfig_file_path(kubeconifg))
    |> Shell.info()
  end

  def execute(kubeconifg, true, true, false) do
    kubeconifg
    |> RancherHttpClient.get_kubeconfig!()
    |> save_to_file!()
    |> Shell.info()
  end

  def kf_valid?(kubeconifg) do
    with path <- kubeconfig_file_path(kubeconifg),
         true <- File.exists?(path) do
      case System.cmd("kubectl", ["get", "pods", "--kubeconfig=#{path}"], stderr_to_stdout: true) do
        {_, 0} -> true
        {_, 1} -> false
      end
    else
      false -> false
    end
  end

  def save_to_file!(target_cluster) do
    with :ok <- File.mkdir_p(kubeconfig_dir()),
         kb_path <- kubeconfig_file_path(target_cluster),
         :ok <- File.write(kb_path, target_cluster.kubeconfig) do
      Shell.info_stderr(["new kubeconfig is saved to ", kb_path])
      kb_path
    else
      {:error, err} -> Shell.raise(["error when saving kubeconfig:\n", err])
    end
  end

  def parse_cluster(raw_clusters) when is_list(raw_clusters) and length(raw_clusters) > 0 do
    raw_clusters |> Enum.map(&%__MODULE__{id: &1["id"], name: &1["name"]})
  end

  def select_cluster(clusters, cluster_name_substring) do
    case Enum.filter(clusters, &String.contains?(&1.name, cluster_name_substring)) do
      [] ->
        {:error, "no match were found for the cluster name '#{cluster_name_substring}'"}

      [cluster] ->
        {:ok, cluster}

      [_ | _] = matched_clusters ->
        Shell.error(
          "more than one matches were found for the cluster name '#{cluster_name_substring}'\nthese matches are found:\n"
        )

        error_char_data =
          matched_clusters
          |> Enum.map(&[" ", &1.name, "\n"])

        Shell.error("#{error_char_data}")

        {:error,
         "please make your cluster name more precise so that there will only be one single match"}
    end
  end

  defp kubeconfig_dir() do
    Path.join(Config.home_dir(), "kubeconfigs")
  end

  def kubeconfig_file_path(kubeconfig) do
    Path.join(
      kubeconfig_dir(),
      kubeconfig.name
    )
  end

  defp sh_template_path do
    :code.priv_dir(:rr)
    |> to_string()
    |> Path.join("templates/sh.eex")
  end
end
