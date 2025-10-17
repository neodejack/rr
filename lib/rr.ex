defmodule RR do
  require Logger
  use Task

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    [cmd | args] = Burrito.Util.Args.argv()

    case cmd do
      "kf" ->
        RR.KubeConfig.run(args)

      "login" ->
        RR.Login.run(args)

      cmd ->
        Logger.error("no such commands #{cmd}")
    end

    System.halt(0)
  end
end
