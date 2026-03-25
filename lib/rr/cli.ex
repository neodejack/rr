defmodule RR.CLI do
  @moduledoc false
  alias RR.CLI.Commands.Alias
  alias RR.CLI.Commands.Kf
  alias RR.CLI.Commands.List
  alias RR.CLI.Commands.Login
  alias RR.CLI.Commands.Yo
  alias RR.CLI.Output

  def run(argv) do
    case argv do
      [cmd | args] ->
        case cmd do
          "kf" ->
            Kf.run(args)

          "login" ->
            Login.run(args)

          "alias" ->
            Alias.run(args)

          "list" ->
            List.run(args)

          "yo" ->
            Yo.run(args)

          "--help" ->
            render_help()

          "-h" ->
            render_help()

          "--version" ->
            render_version()

          "-v" ->
            render_version()

          _cmd ->
            {:error, "no such commands #{cmd}"}
        end

      [] ->
        render_help()
    end
  end

  defp render_version do
    Output.info_stdout(Application.spec(:rr)[:vsn])
    :ok
  end

  defp render_help do
    Output.info_stdout("""
    playing with rancher generated kubeconfigs

    COMMANDS
      login     : key in the auth info of rancher cluster
      kf        : playing with rancher generated kubeconfigs
      list      : list rancher clusters
      yo        : output shell integration (zsh/bash)
    """)

    Output.info_stdout(["current version: ", Application.spec(:rr)[:vsn]])
    :ok
  end
end
