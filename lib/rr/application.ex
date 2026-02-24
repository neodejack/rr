defmodule RR.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    if Application.get_env(:rr, :run_cli, false) do
      RR.main()
    end

    Supervisor.start_link([], strategy: :one_for_one, name: RR.Supervisor)
  end
end
