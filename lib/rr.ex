defmodule RR do
  @moduledoc false

  def main do
    code =
      try do
        case run(Burrito.Util.Args.argv()) do
          :ok ->
            0

          {:error, msg} ->
            RR.Shell.error(msg)
            1
        end
      rescue
        e ->
          RR.Shell.error(Exception.message(e))
          1
      end

    System.halt(code)
  end

  def run(argv) do
    case argv do
      [cmd | args] ->
        case cmd do
          "kf" ->
            RR.KubeConfig.run(args)

          "login" ->
            RR.Login.run(args)

          "alias" ->
            RR.Alias.run(args)

          "list" ->
            RR.List.run(args)

          "yo" ->
            RR.Yo.run(args)

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
    RR.Shell.info_stdout(Application.spec(:rr)[:vsn])
    :ok
  end

  defp render_help do
    RR.Shell.info_stdout("""
    playing with rancher generated kubeconfigs

    COMMANDS
      login     : key in the auth info of rancher cluster
      kf        : playing with rancher generated kubeconfigs
      list      : list rancher clusters
      yo        : output shell integration (zsh/bash)
    """)

    RR.Shell.info_stdout(["current version: ", Application.spec(:rr)[:vsn]])
    :ok
  end
end
