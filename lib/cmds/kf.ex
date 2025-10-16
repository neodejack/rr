defmodule RR.KubeConfig do
  alias RR.KubeConfig
  alias RR.Shell
  require Logger

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :kubeconfig]

  def parse_args(args) do
    case OptionParser.parse(args, strict: args_definition()) do
      {switches, [cluster], []} ->
        {switches, cluster}

      {_switches, [_ | _] = clusters, []} ->
        Shell.raise([
          "you provided more than one clusters: ",
          Enum.intersperse(clusters, ", ")
        ])

      {_switches, _clusters, invalid_args} ->
        invalids = invalid_args |> Enum.map(fn {arg, _value} -> arg end)

        Shell.raise([
          "the arguments you provided are invalid: ",
          invalids
        ])
    end
  end

  def args_definition() do
    [
      zsh: :boolean
    ]
  end

  def run(args) do
    {switches, fuzzy_cluster_name} = parse_args(args)

    target_cluster =
      cluster_selection(fuzzy_cluster_name)

    kf_path =
      target_cluster
      |> get_kubeconfig!()
      |> save_to_file()

    if Keyword.get(switches, :zsh, false) do
      Shell.info(EEx.eval_file(zsh_template_path(), kf_path: kf_path))
    end
  end

  def cluster_selection(fuzzy_cluster_name) do
    with true <- rancher_logged_in?(),
         clusters <- get_clusters!() do
      select_cluster!(clusters, fuzzy_cluster_name)
    end
  end

  def get_kubeconfig!(target_cluster) do
    %Req.Response{status: status} =
      resp =
      Req.post!(base_req(), url: "/v3/clusters/#{target_cluster.id}?action=generateKubeconfig")

    case status do
      200 ->
        %{target_cluster | kubeconfig: resp.body["config"]}

      _ ->
        raise "`rancher cluster kf` failed"
    end
  end

  def save_to_file(target_cluster) do
    with :ok <- File.mkdir_p(kubeconfig_dir()),
         kb_path <- new_kubeconfig_file_path(target_cluster),
         :ok <- File.write(kb_path, target_cluster.kubeconfig) do
      kb_path
    else
      {:error, err} -> raise "error when saving kubeconfig: #{err}"
    end
  end

  def get_clusters!() do
    case Req.get!(base_req(), url: "/v3/clusters") do
      %Req.Response{status: 200} = resp ->
        parse_cluster(resp.body["data"])

      _ ->
        raise "failed to get clusters"
    end
  end

  def parse_cluster(raw_clusters) do
    raw_clusters |> Enum.map(&%KubeConfig{id: &1["id"], name: &1["name"]})
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

  def base_req do
    conf = Application.get_env(:rr, RR)

    Req.new(
      base_url: conf[:rancher_hostname],
      auth: {:bearer, conf[:rancher_token]}
    )
  end

  def rancher_logged_in? do
    case Req.get!(base_req(), url: "/v3/clusters") do
      %Req.Response{status: 200} ->
        true

      %Req.Response{status: 401} = resp ->
        Shell.error("not logged in or token has expired")
        Shell.error("#{resp.body["message"]}")

        Shell.error("to login, run: rancher login <Rancher Host> --token <Bearer Token>")
        Shell.error("<Rancher Host> is https://cmgmt.truewatch.io/v3")

        Shell.error(
          "<Bearer Token> can be abtained at https://cmgmt.truewatch.io/dashboard/account/create-key"
        )

        false
    end
  end

  def kubeconfig_dir() do
    Path.expand("~/.rr/secure-configs")
  end

  def new_kubeconfig_file_path(kubeconfig) do
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
