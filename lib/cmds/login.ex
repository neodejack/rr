defmodule RR.Login do
  @moduledoc """
  three finite state: [:no_auth_config, :invalid_auth_config, :valid_auth_config]
  login/1 function will pattern match on these three and proceed to respective actions

  """
  alias RR.Config.Auth
  alias RR.Shell

  def run(args) do
    with :ok <- parse_args(args),
         {:ok, auth} <- Auth.ensure_valid_auth(),
         {:ok, token_info} <- External.RancherHttpClient.get_token_info(auth),
         true <-
           Owl.IO.confirm(
             message: [
               "you already have a valid auth config with description '#{token_info.description}',",
               "are you sure you want to overwrite it?"
             ]
           ) do
      login()
    else
      false -> :ok
      {:error, :unauthorized, _} -> login()
      {:error, :unknown, message} -> {:error, message}
      {:error, _} -> login()
    end
  end

  defp parse_args(args) do
    case args do
      [] ->
        :ok

      _ ->
        {:error, "rr login command doesn't take any args\nyou provided: #{Enum.join(args, " ")}"}
    end
  end

  defp login do
    auth = prompt()

    case Auth.check_auth_validity_from_ets_or_rancher(auth) do
      {:ok, auth} ->
        Auth.put_auth(auth)
        Shell.info("token successfully validated and saved")
        :ok

      {:error, :unauthorized, reason} ->
        {:error, "token validation failed with reason: \n#{reason}"}

      {:error, :unknown, reason} ->
        {:error, "token validation failed with reason: \n#{reason}"}

      {:error, reason} ->
        {:error, "token validation failed with reason: \n#{reason}"}
    end
  end

  defp prompt do
    hostname = Owl.IO.input(label: "rancher hostname")
    token = Owl.IO.input(label: "rancher token (in the form of token-xxxx:xxxxxx)", secret: true)

    %Auth{rancher_hostname: hostname, rancher_token: token}
  end
end
