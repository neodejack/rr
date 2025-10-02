defmodule RR.Kf do
  require Logger

  def run(_switches) do
    cluster_id =
      cluster_selection()

    kf_path =
      cluster_id
      |> get_kubeconfig!()
      |> save_to_file()

    IO.puts(kf_path)
  end

  def cluster_selection() do
    with true <- rancher_logged_in?(),
         clusters <- get_clusters!() do
      clusters
      |> select_cluster()
      |> get_cluster_id_by_name(clusters)
    end
  end

  def get_kubeconfig!(cluster_id) do
    %Req.Response{status: status} =
      resp = Req.post!(base_req(), url: "/v3/clusters/#{cluster_id}?action=generateKubeconfig")

    case status do
      200 ->
        resp.body["config"]

      _ ->
        raise "`rancher cluster kf` failed"
    end
  end

  def save_to_file(kubeconfig) do
    with :ok <- File.mkdir_p(kubeconfig_dir()),
         kb_path <- new_kubeconfig_file_path(),
         :ok <- File.write(kb_path, kubeconfig) do
      kb_path
    else
      {:error, err} -> raise "error when saving kubeconfig: #{err}"
    end
  end

  def get_cluster_id_by_name(name, clusters) do
    case Enum.find(clusters, &(&1.name == name)) do
      nil ->
        raise "user's selected cluster not found. user_selection: #{name}"

      cluster ->
        cluster.id
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
    raw_clusters |> Enum.map(&%{id: &1["id"], name: &1["name"]})
  end

  def select_cluster(clusters) do
    Owl.IO.select(Enum.map(clusters, & &1.name))
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

  def new_kubeconfig_file_path() do
    Path.join(
      kubeconfig_dir(),
      :crypto.strong_rand_bytes(10) |> Base.url_encode64(padding: false)
    )
  end
end
