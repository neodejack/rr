defmodule RR.KubeConfig do
  alias RR.Alias
  alias RR.Shell
  alias RR.Config
  require Logger

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :kubeconfig]

  def run(args) do
    {switches, cluster_name_substring} = parse_args!(args)

    if Keyword.has_key?(switches, :help) do
      render_help()
    end

    cluster_name_substring = Alias.resolve(cluster_name_substring)

    target_cluster =
      base_req!()
      |> get_clusters!()
      |> select_cluster!(cluster_name_substring)

    execute(
      target_cluster,
      kf_valid?(target_cluster),
      Keyword.get(switches, :new, false),
      Keyword.get(switches, :sh, false)
    )
  end

  def parse_args!(args) do
    case OptionParser.parse(args, args_definition()) do
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
    |> get_kubeconfig!(base_req!())
    |> save_to_file!()

    sh_template_path()
    |> EEx.eval_file(kf_path: kubeconfig_file_path(kubeconifg))
    |> Shell.info()
  end

  def execute(kubeconifg, false, _overwrite_existing_kf, false) do
    kubeconifg
    |> get_kubeconfig!(base_req!())
    |> save_to_file!()
    |> Shell.info()
  end

  def execute(kubeconifg, true, false, true) do
    sh_template_path()
    |> EEx.eval_file(kf_path: kubeconfig_file_path(kubeconifg))
    |> Shell.info()
  end

  def execute(kubeconifg, true, false, false) do
    kubeconifg
    |> kubeconfig_file_path()
    |> Shell.info()
  end

  def execute(kubeconifg, true, true, true) do
    kubeconifg
    |> get_kubeconfig!(base_req!())
    |> save_to_file!()

    sh_template_path()
    |> EEx.eval_file(kf_path: kubeconfig_file_path(kubeconifg))
    |> Shell.info()
  end

  def execute(kubeconifg, true, true, false) do
    kubeconifg
    |> get_kubeconfig!(base_req!())
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

  def get_kubeconfig!(target_cluster, base_req) do
    url = "/v3/clusters/#{target_cluster.id}?action=generateKubeconfig"

    %Req.Response{status: status} =
      resp =
      Req.post!(base_req, url: url)

    case status do
      200 ->
        %{target_cluster | kubeconfig: resp.body["config"]}

      _ ->
        Shell.raise([
          "http request to rancher api failed.\n",
          "request url: ",
          url,
          "\nerror response:\n",
          inspect(resp.body)
        ])
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

  def get_clusters!(base_req) do
    case Req.get!(base_req, url: "/v3/clusters") do
      %Req.Response{status: 200} = resp ->
        parse_cluster(resp.body["data"])

      _ ->
        raise "failed to get clusters"
    end
  end

  def parse_cluster(raw_clusters) do
    raw_clusters |> Enum.map(&%__MODULE__{id: &1["id"], name: &1["name"]})
  end

  def select_cluster!(clusters, cluster_name_substring) do
    case Enum.filter(clusters, &String.contains?(&1.name, cluster_name_substring)) do
      [] ->
        Shell.raise("no match were found for the cluster name '#{cluster_name_substring}'")

      [cluster] ->
        cluster

      [_ | _] = matched_clusters ->
        Shell.error(
          "more than one matches were found for the cluster name '#{cluster_name_substring}'\nthese matches are found:\n"
        )

        error_char_data =
          matched_clusters
          |> Enum.map(&[" ", &1.name, "\n"])

        Shell.error("#{error_char_data}")

        Shell.raise(
          "please make your cluster name more precise so that there will only be one single match"
        )
    end
  end

  def base_req! do
    with {:ok, auth} <- RR.Config.Auth.get_auth(),
         true <- RR.Config.Auth.is_valid_auth?(auth) do
      Req.new(
        base_url: auth.rancher_hostname,
        auth: {:bearer, auth.rancher_token}
      )
    else
      {:error, err} ->
        Shell.raise(err)

      false ->
        Shell.raise("")
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
