defmodule RR.Login do
  @moduledoc """
  three finite state: [:no_auth_config, :invalid_auth_config, :valid_auth_config]
  login/1 function will pattern match on these three and proceed to respective actions

  """
  alias RR.Shell

  @enforce_keys [:state]
  @derive {JSON.Encoder, only: [:rancher_hostname, :rancher_token]}
  defstruct [:state, :rancher_hostname, :rancher_token]

  def run(args) do
    parse_args!(args)

    %__MODULE__{state: :no_auth_config}
    |> login()
  end

  def parse_args!(args) do
    case args do
      [] ->
        :ok

      _ ->
        Shell.raise(["rr login command doesn't take any args\n", "you provided: ", args])
    end
  end

  def login(%__MODULE__{state: :no_auth_config} = auth) do
    auth |> prompt() |> is_validate_auth!() |> write_to_config_file()
    :ok
  end

  def prompt(auth) do
    hostname = Owl.IO.input(label: "rancher hostname")
    token = Owl.IO.input(label: "rancher token (in the form of token-xxxx:xxxxxx)", secret: true)
    %{auth | rancher_hostname: hostname, rancher_token: token}
  end

  def base_req(auth) do
    Req.new(
      base_url: auth.rancher_hostname,
      auth: {:bearer, auth.rancher_token}
    )
  end

  def is_validate_auth!(auth) do
    case Req.get!(base_req(auth), url: "/v3/clusters") do
      %Req.Response{status: 200} ->
        auth

      %Req.Response{status: 401} ->
        Shell.error("validation of auth config failed")
        Shell.raise("make sure your hostname and token are correct and try again")

      resp ->
        Shell.raise(["unexpected error when validating auth\n", inspect(resp)])
    end
  end

  def write_to_config_file(auth) do
    auth_json = JSON.encode!(auth)
    File.write!(Application.get_env(:rr, RR)[:config_path], auth_json)
    auth
  end
end
