defmodule External.RancherHttpClient.Impl do
  @moduledoc false
  @behaviour External.RancherHttpClient

  alias RR.Config.Auth
  alias RR.KubeConfig
  alias RR.Shell

  @impl true
  def auth_validation(%Auth{rancher_hostname: rancher_hostname, rancher_token: rancher_token}) do
    case Req.get([base_url: rancher_hostname, auth: {:bearer, rancher_token}], url: "/v3/clusters") do
      {:ok, %Req.Response{status: 200}} ->
        :ok

      {:ok, %Req.Response{status: 401}} ->
        Shell.error("your token or hostname is invalid")
        Shell.error("to login, run: rr login")

        :error

      {_, resp} ->
        Shell.error("#{inspect(resp)}")
        :error
    end
  end

  @impl true
  def get_clusters do
    url = "/v3/clusters"

    case Req.get!(rancher_base_req!(), url: url) do
      %Req.Response{status: 200, body: body} ->
        if length(body["data"]) > 0 do
          {:ok, body["data"]}
        else
          {:error, "no clusters info found"}
        end

      non_200_resp ->
        Shell.error(inspect(non_200_resp))
        {:error, "http error for #{url}"}
    end
  end

  @impl true
  def get_kubeconfig!(%KubeConfig{id: id} = kubeconfig) do
    url = "/v3/clusters/#{id}?action=generateKubeconfig"

    %Req.Response{status: status} =
      resp = Req.post!(rancher_base_req!(), url: url)

    case status do
      200 ->
        %{kubeconfig | kubeconfig: resp.body["config"]}

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

  defp rancher_base_req! do
    with {:ok, auth} <- Auth.get_auth(),
         true <- Auth.valid_auth?(auth) do
      Req.new(
        base_url: auth.rancher_hostname,
        auth: {:bearer, auth.rancher_token}
      )
    else
      {:error, err} ->
        Shell.raise(err)

      false ->
        Shell.raise("auth not valid")
    end
  end
end
