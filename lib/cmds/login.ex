defmodule RR.Login do
  @moduledoc """
  three finite state: [:no_auth_config, :invalid_auth_config, :valid_auth_config]
  login/1 function will pattern match on these three and proceed to respective actions

  """
  alias RR.Config.Auth
  alias RR.Shell

  def run(args) do
    with :ok <- parse_args!(args),
         {:ok, auth} <- Auth.ensure_valid_auth(),
         {:ok, token_info} <- External.RancherHttpClient.get_token_info(auth),
         true <-
           Owl.IO.confirm(
             message: [
               "you already have a valid auth config with description '#{token_info.token_description}',",
               "are you sure you want to overwrite it?"
             ]
           ) do
      login()
    else
      {:error, _} -> login()
      false -> :ok
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

    case Auth.check_auth_validity_from_ets_or_rancher(auth) do
      {:ok, auth} ->
        Auth.put_auth(auth)
        Shell.info("token successfully validated and saved")

      {:error, reason} ->
        Shell.raise("token validation failed with reason: \n#{reason}")
    end
  end

  def prompt do
    hostname = Owl.IO.input(label: "rancher hostname")
    token = Owl.IO.input(label: "rancher token (in the form of token-xxxx:xxxxxx)", secret: true)

    %Auth{rancher_hostname: hostname, rancher_token: token}
  end
end
