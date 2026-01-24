defmodule RR do
  @moduledoc false
  use Task

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    case Burrito.Util.Args.argv() do
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

          "zsh" ->
            RR.Zsh.run(args)

          "--help" ->
            render_help()

          "-h" ->
            render_help()

          "--version" ->
            render_version()

          "-v" ->
            render_version()

          _cmd ->
            RR.Shell.error("no such commands #{cmd}")
        end

      [] ->
        render_help()
    end

    System.halt(0)
  end

  def render_version do
    RR.Shell.info(Application.spec(:rr)[:vsn])
  end

  def render_help do
    RR.Shell.info("""
    playing with rancher generated kubeconfigs

    COMMANDS
      login     : key in the auth info of rancher cluster
      kf        : playing with rancher generated kubeconfigs
      list      : list rancher clusters
      zsh       : output zsh integration
    """)

    RR.Shell.info(["current version: ", Application.spec(:rr)[:vsn]])
  end
end
