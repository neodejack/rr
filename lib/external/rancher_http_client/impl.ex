defmodule External.RancherHttpClient.Impl do
  @moduledoc false
  @behaviour External.RancherHttpClient

  alias RR.Config.Auth
  alias RR.KubeConfig
  alias RR.Shell

  @impl true
  def get_clusters do
    url = "/v3/clusters"

    with {:ok, req} <- rancher_base_req() do
      case Req.get!(req, url: url) do
        %Req.Response{status: 200, body: body} ->
          if [] == body["data"] do
            {:error, "no clusters info found"}
          else
            {:ok, body["data"]}
          end

        non_200_resp ->
          Shell.error(inspect(non_200_resp))
          {:error, "http error for #{url}"}
      end
    end
  end

  @impl true
  def get_kubeconfig(%KubeConfig{id: id} = kubeconfig) do
    url = "/v3/clusters/#{id}?action=generateKubeconfig"

    with {:ok, req} <- rancher_base_req() do
      case Req.post!(req, url: url) do
        %Req.Response{status: 200} = resp ->
          {:ok, %{kubeconfig | kubeconfig: resp.body["config"]}}

        resp ->
          {:error,
           IO.iodata_to_binary([
             "http request to rancher api failed.\n",
             "request url: ",
             url,
             "\nerror response:\n",
             inspect(resp.body)
           ])}
      end
    end
  end

  @impl true
  def get_token_info(%Auth{rancher_hostname: rancher_hostname, rancher_token: rancher_token}) do
    token_id = rancher_token |> String.split(":") |> hd()

    url = "#{rancher_hostname}/v3/tokens/#{token_id}"

    case Req.get(url, auth: {:bearer, rancher_token}) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok,
         %{
           description: body["description"],
           expired: body["expired"],
           enabled: body["enabled"],
           created_ts: body["createdTS"],
           ttl: body["ttl"]
         }}

      {:ok, %Req.Response{status: status}} when status in [401, 403] ->
        {:error, :unauthorized, "rancher token is not valid or has expired"}

      {:ok, resp} ->
        {:error, :unknown, "rancher api error - GET #{url}\n#{inspect(resp.body)}"}

      {_, error} ->
        {:error, :unknown, "rancher api error - GET #{url}\n#{inspect(error)}"}
    end
  end

  defp rancher_base_req do
    case Auth.ensure_valid_auth() do
      {:ok, auth} ->
        {:ok,
         Req.new(
           base_url: auth.rancher_hostname,
           auth: {:bearer, auth.rancher_token}
         )}

      {:error, :unauthorized, err} ->
        {:error, err}

      {:error, :unknown, err} ->
        {:error, err}

      {:error, _} = error ->
        error
    end
  end
end
