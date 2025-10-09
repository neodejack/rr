defmodule RR.KubeConfig do
  alias RR.KubeConfig
  require Logger

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :kubeconfig]

  def run(switches) do
    target_cluster =
      cluster_selection()

    kf_path =
      target_cluster
      |> get_kubeconfig!()
      |> save_to_file()

    if Keyword.get(switches, :zsh, false) do
      IO.puts(EEx.eval_file(Path.join(__DIR__, "zsh.eex"), kf_path: kf_path))
    end
  end

  def cluster_selection() do
    with true <- rancher_logged_in?(),
         clusters <- get_clusters!() do
      case clusters |> select_cluster() do
        {:ok, selected_cluster_id} -> Enum.find(clusters, &(&1.id == selected_cluster_id))
        {:error, msg} -> raise msg
      end
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

  def select_cluster(clusters) do
    {:ok, tui} =
      Breeze.Server.start_link(
        view: RR.Cmds.Tui.SelectCluster,
        hide_cursor: true,
        start_opts: [receiver: self(), clusters: clusters]
      )

    receive do
      {:selected, selected_cluster_id} ->
        GenServer.stop(tui)
        {:ok, selected_cluster_id}

      {:quit} ->
        GenServer.stop(tui)
        {:error, "user quited"}
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
end
