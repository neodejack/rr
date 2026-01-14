defmodule External.RancherHttpClient do
  @type req_resp() :: {:ok, Req.Response.t()} | {:error, Exception.t()}

  @callback auth_validation(%RR.Config.Auth{}) :: req_resp()

  def auth_validation(auth), do: impl().auth_validation(auth)

  def impl(),
    do: Module.concat([__MODULE__, Application.get_env(:rr, :external_bound, Impl)])
end
