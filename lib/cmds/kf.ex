defmodule RR.KubeConfig do
  alias RR.Shell
  alias RR.Config
  require Logger

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :kubeconfig]

  def parse_args!(args) do
    case OptionParser.parse(args, strict: args_definition()) do
      {switches, [cluster], []} ->
        {switches, cluster}

      {_switches, [_cluster], invalid_args} ->
        invalids = invalid_args |> Enum.map(fn {arg, _value} -> arg end)

        Shell.raise([
          "the arguments you provided are invalid: ",
          invalids
        ])

      {_switches, [], _} ->
        Shell.raise([
          "you didn't specify a fuzzy cluster name"
        ])

      {_switches, [_ | _] = clusters, _} ->
        Shell.raise([
          "you provided more than one clusters: ",
          Enum.intersperse(clusters, ", ")
        ])
    end
  end

  def args_definition() do
    [
      zsh: :boolean,
      new: :boolean
    ]
  end

  def run(args) do
    {switches, fuzzy_cluster_name} = parse_args!(args)

    base_req = base_req!()

    target_cluster =
      cluster_selection(fuzzy_cluster_name, base_req)

    kf_path =
      target_cluster
      |> get_kubeconfig!(base_req)
      |> save_to_file()

    Shell.error(["kubeconfig is saved to: ", kf_path])

    if Keyword.get(switches, :zsh, false) do
      Shell.info(EEx.eval_file(zsh_template_path(), kf_path: kf_path))
    end
  end

  def existing_kf_is_valid?(target_cluster) do
    path = kubeconfig_file_path(target_cluster)

    with true <- File.exists?(path) do
      case System.cmd("kubectl", ["get", "pods", "--kubeconfig=#{path}"], stderr_to_stdout: true) do
        {_, 0} -> true
        {_, 1} -> false
      end
    else
      false -> false
    end
  end

  def cluster_selection(fuzzy_cluster_name, base_req) do
    get_clusters!(base_req) |> select_cluster!(fuzzy_cluster_name)
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

  def save_to_file(target_cluster) do
    with :ok <- File.mkdir_p(kubeconfig_dir()),
         kb_path <- kubeconfig_file_path(target_cluster),
         :ok <- File.write(kb_path, target_cluster.kubeconfig) do
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

  def select_cluster!(clusters, fuzzy_cluster_name) do
    case Enum.filter(clusters, &String.contains?(&1.name, fuzzy_cluster_name)) do
      [] ->
        Shell.raise("no match were found for the cluster name '#{fuzzy_cluster_name}'")

      [cluster] ->
        cluster

      [_ | _] = matched_clusters ->
        Shell.error(
          "more than one matches were found for the cluster name '#{fuzzy_cluster_name}'\nthese matches are found:"
        )

        error_char_data =
          matched_clusters
          |> Enum.map(&[" - ", &1.name, "\n"])

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

  defp zsh_template_path do
    :code.priv_dir(:rr)
    |> to_string()
    |> Path.join("templates/zsh.eex")
  end
end
