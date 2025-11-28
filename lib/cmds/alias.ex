defmodule RR.Alias do
  alias RR.Shell
  alias RR.Config
  require Logger

  def run(args) do
    {_, alias, full_name} = parse_args!(args)

    Config.put_in([Access.key("alias", %{}), alias], full_name)
    Shell.info("alias: #{alias} -> #{full_name} ")
  end

  def resolve(alias) do
    case Config.get_in(["alias", alias]) do
      nil ->
        alias

      full_name ->
        Shell.info("resolving alias: #{alias} -> #{full_name} ")
        full_name
    end
  end

  def parse_args!(args) do
    with {switches, _, _} = args <- OptionParser.parse(args, args_definition()),
         false <- Keyword.has_key?(switches, :help) do
      case args do
        {switches, [alias, full], []} ->
          {switches, alias, full}

        {_switches, _cluster, [_invalid | _] = invalid_args} ->
          invalids = invalid_args |> Enum.map(fn {arg, _value} -> arg end)

          Shell.error([
            "the arguments you provided are invalid:",
            invalids
          ])

          render_help()

        {_switches, _cluster, _} ->
          Shell.error([
            "you didn't provide valid <cluster_alias> and <cluster_full_name>"
          ])

          render_help()
      end
    else
      true -> render_help()
    end
  end

  def args_definition() do
    [
      strict: [
        help: :boolean
      ],
      alias: [h: :help]
    ]
  end

  def render_help() do
    Shell.info("""

    `rr alias` set alias. 
    alias will be substituted when used in `rr kf <alias>

    USAGE:
      rr alias <cluster_alias> <cluster_full_name>

    """)

    System.halt(0)
  end
end
