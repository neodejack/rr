defmodule RR do
  require Logger
  use Task

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    with [cmd | args] <- Burrito.Util.Args.argv() do
      case cmd do
        "kf" ->
          RR.KubeConfig.run(args)

        "login" ->
          RR.Login.run(args)

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
    else
      [] -> render_help()
    end

    System.halt(0)
  end

  def render_version do
    Application.spec(:rr)[:vsn] |> RR.Shell.info()
  end

  def render_help() do
    RR.Shell.info("""
    playing with rancher generated kubeconfigs

    COMMANDS
      login     : key in the auth info of rancher cluster
      kf        : playing with rancher generated kubeconfigs

    """)

    render_version()
  end
end
