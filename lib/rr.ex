defmodule RR do
  require Logger
  use Task

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    {switches, [cmd | sub_cmds]} = parse_args()

    case cmd do
      "kf" ->
        RR.KubeConfig.run(switches, sub_cmds)
        :init.stop()

      cmd ->
        Logger.error("no such commands #{cmd}")
        :init.stop()
    end
  end

  def parse_args() do
    {switches, cmds, invalid} =
      OptionParser.parse(Burrito.Util.Args.argv(), strict: args_definition())

    case invalid do
      [] ->
        {switches, cmds}

      [_ | _] ->
        Logger.error("the arguments you provided are invalid")
        :init.stop()
    end
  end

  def args_definition() do
    [
      help: :boolean,
      zsh: :boolean
    ]
  end
end
