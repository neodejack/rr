defmodule RR.Config.Auth do
  alias RR.Config
  defstruct [:rancher_hostname, :rancher_token]

  def get_auth() do
    %__MODULE__{
      rancher_hostname: Config.get("rancher_hostname"),
      rancher_token: Config.get("rancher_token")
    }
  end

  def put_auth(auth) do
    Config.put("rancher_hostname", auth.rancher_hostname)
    Config.put("rancher_token", auth.rancher_token)
  end
end
