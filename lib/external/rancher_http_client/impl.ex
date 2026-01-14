defmodule External.RancherHttpClient.Impl do
  @behaviour External.RancherHttpClient

  @impl External.RancherHttpClient
  def auth_validation(%RR.Config.Auth{
        rancher_hostname: rancher_hostname,
        rancher_token: rancher_token
      }) do
    Req.new(
      base_url: rancher_hostname,
      auth: {:bearer, rancher_token}
    )
    |> Req.get(url: "/v3/clusters")
    |> dbg()
  end
end
