defmodule RR do
  require Logger

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

  def base_req do
    Req.new(
      base_url: Application.get_env(:rr, :rancher_hostname),
      auth: {:bearer, Application.get_env(:rr, :rancher_token)}
    )
  end
end
