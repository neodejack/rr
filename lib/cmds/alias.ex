defmodule RR.Alias do
  alias RR.Shell
  alias RR.Config
  require Logger

  def run(args) do
    {alias, full_name} = parse_args!(args)

    Config.put_in([Access.key("alias", %{}), alias], full_name)
    Shell.info("alias: #{alias} -> #{full_name} ")
  end

  def resolve(alias) do
    case Config.get_in(["alias", alias]) do
      nil ->
        alias

      full_name ->
        Shell.info_stderr("resolving alias: #{alias} -> #{full_name} ")
        full_name
    end
  end

  def parse_args!(args) do
    with {switches, _, _} = args <- OptionParser.parse(args, args_definition()),
         false <- Keyword.has_key?(switches, :help) do
      if Keyword.has_key?(switches, :list) do
        render_alias_list()
      end

      case args do
        {_, [alias, full], []} ->
          {alias, full}

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
        help: :boolean,
        list: :boolean
      ],
      alias: [h: :help]
    ]
  end

  def render_alias_list() do
    aliases = Config.get_in(["alias"])

    case map_size(aliases) > 0 do
      true ->
        Shell.info("these aliases are found:\n")

        aliases
        |> Enum.map(fn {alias, full_name} -> "  #{alias} -> #{full_name}\n" end)
        |> Shell.info()

      false ->
        Shell.info("no aliases set")
    end

    System.halt(0)
  end

  def render_help() do
    Shell.info("""

    `rr alias` set alias. 
    alias will be substituted when used in `rr kf <alias>

    USAGE:
      rr alias <cluster_alias> <cluster_full_name>
      rr alias --list

    FlAGS:
      --list List all the aliases currently set
    """)

    System.halt(0)
  end
end
