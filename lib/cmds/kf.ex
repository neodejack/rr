defmodule RR.KubeConfig do
  alias RR.KubeConfig
  require Logger

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :kubeconfig]

  def run(switches, fuzzy_cluster_name) do
    target_cluster =
      cluster_selection(fuzzy_cluster_name)

    kf_path =
      target_cluster
      |> get_kubeconfig!()
      |> save_to_file()

    if Keyword.get(switches, :zsh, false) do
      IO.puts(EEx.eval_file(zsh_template_path(), kf_path: kf_path))
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
        Logger.error("no match were found for the cluster name '#{fuzzy_cluster_name}'")
        raise "error"

      [cluster] ->
        cluster

      [_ | _] = matched_clusters ->
        Logger.error(
          "more than one matches were found for the cluster name '#{fuzzy_cluster_name}'
          these matches are found:"
        )

        error_string =
          Enum.reduce(matched_clusters, "", fn cluster, error_string ->
            error_string <> cluster.name <> "\n"
          end)

        Logger.error("#{error_string}")

        Logger.error(
          "please make your cluster name more precise so that there will only be one single match"
        )

        raise "error"
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
        Logger.error("not logged in or token has expired")
        Logger.error("#{resp.body["message"]}")

        Logger.info("to login, run: rancher login <Rancher Host> --token <Bearer Token>")
        Logger.info("<Rancher Host> is https://cmgmt.truewatch.io/v3")

        Logger.info(
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
