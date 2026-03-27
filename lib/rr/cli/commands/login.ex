defmodule RR.CLI.Commands.Login do
  @moduledoc """
  three finite state: [:no_auth_config, :invalid_auth_config, :valid_auth_config]
  login/1 function will pattern match on these three and proceed to respective actions

  """
  @behaviour RR.CLI.Command

  alias RR.CLI.ParseError
  alias RR.Providers.Rancher
  alias RR.Providers.Terminal
  alias RR.Services.Auth

  defstruct []

  @impl true
  def build_action(_switches, rest) do
    case rest do
      [] ->
        {:ok, %__MODULE__{}}

      _ ->
        {:error,
         %ParseError{
           module: __MODULE__,
           message: "rr login command doesn't take any args\nyou provided: #{Enum.join(rest, " ")}"
         }}
    end
  end

  @impl true
  def execute(%__MODULE__{}) do
    with {:ok, auth} <- Auth.ensure_valid_auth(),
         {:ok, token_info} <- Rancher.get_token_info(auth),
         true <-
           Terminal.confirm(
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

  @impl true
  def summary, do: "key in the auth info of rancher cluster"

  @impl true
  def help do
    """
    key in the auth info of rancher cluster

    USAGE:
      rr login
    """
  end

  @impl true
  def args_definition do
    [
      strict: [
        help: :boolean
      ],
      alias: [h: :help]
    ]
  end

  defp login do
    auth = prompt()

    case Auth.check_auth_validity(auth) do
      {:ok, auth} ->
        Auth.put_auth(auth)
        Terminal.info_stdout("token successfully validated and saved")
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
    hostname = Terminal.input(label: "rancher hostname")
    token = Terminal.input(label: "rancher token (in the form of token-xxxx:xxxxxx)", secret: true)

    %Auth{rancher_hostname: hostname, rancher_token: token}
  end
end
