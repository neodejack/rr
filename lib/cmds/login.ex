defmodule RR.Login do
  @moduledoc """
  three finite state: [:no_auth_config, :invalid_auth_config, :valid_auth_config]
  login/1 function will pattern match on these three and proceed to respective actions

  """
  alias RR.Config.Auth
  alias RR.Shell

  def run(args) do
    with :ok <- parse_args!(args),
         {:ok, auth} <- Auth.get_auth(),
         true <- Auth.valid_auth?(auth) do
      if Owl.IO.confirm(message: "you already have a valid auth config, are you sure you want to overwrite it?") do
        login()
      else
        :ok
      end
    else
      {:error, _} -> login()
      false -> login()
    end
  end

  def parse_args!(args) do
    case args do
      [] ->
        :ok

      _ ->
        Shell.raise(["rr login command doesn't take any args\n", "you provided: ", args])
    end
  end

  def login do
    auth = prompt()

    if Auth.valid_auth?(auth) do
      Shell.info("auth info successfully validated and saved")
      Auth.put_auth(auth)
    else
      Shell.raise(" ")
    end
  end

  def prompt do
    hostname = Owl.IO.input(label: "rancher hostname")
    token = Owl.IO.input(label: "rancher token (in the form of token-xxxx:xxxxxx)", secret: true)

    %Auth{rancher_hostname: hostname, rancher_token: token}
  end
end
