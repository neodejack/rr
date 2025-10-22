defmodule RR.Config.Auth do
  alias RR.Config
  alias RR.Shell
  defstruct [:rancher_hostname, :rancher_token]

  def get_auth() do
    auth = %__MODULE__{
      rancher_hostname: Config.get("rancher_hostname"),
      rancher_token: Config.get("rancher_token")
    }

    case auth.rancher_hostname != nil and auth.rancher_token != nil do
      true -> {:ok, auth}
      false -> {:error, "auth config file incomplete\nto login, run: rr login"}
    end
  end

  def put_auth(auth) do
    Config.put("rancher_hostname", auth.rancher_hostname)
    Config.put("rancher_token", auth.rancher_token)
  end

  def is_valid_auth?(auth) do
    base_req =
      Req.new(
        base_url: auth.rancher_hostname,
        auth: {:bearer, auth.rancher_token}
      )

    case Req.get(base_req, url: "/v3/clusters") do
      {:ok, %Req.Response{status: 200}} ->
        true

      {:ok, %Req.Response{status: 401} = resp} ->
        Shell.error("your token or hostname is invalid")

        Shell.error("to login, run: rr login")
        false

      {_, resp} ->
        Shell.error("bad auth config")
        Shell.error("#{inspect(resp)}")
        false
    end
  end
end
