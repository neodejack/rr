defmodule RR.Alias do
  @moduledoc false
  alias RR.Config
  alias RR.Shell

  def run(args) do
    with {:ok, {alias_name, full_name}} <- parse_args(args) do
      Config.put_in([Access.key("alias", %{}), alias_name], full_name)
      Shell.info_stdout("alias: #{alias_name} -> #{full_name} ")
      :ok
    end
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

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, ["the arguments you provided are invalid:", invalids]}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      Keyword.has_key?(switches, :list) ->
        render_alias_list()

      match?([_, _], rest) ->
        [alias_name, full] = rest
        {:ok, {alias_name, full}}

      true ->
        render_help()
        {:error, "you didn't provide valid <cluster_alias> and <cluster_full_name>"}
    end
  end

  defp args_definition do
    [
      strict: [
        help: :boolean,
        list: :boolean
      ],
      alias: [h: :help]
    ]
  end

  defp render_alias_list do
    aliases = Config.get_in(["alias"])

    if map_size(aliases) > 0 do
      Shell.info_stdout("these aliases are found:\n")

      aliases
      |> Enum.map(fn {alias_name, full_name} -> "  #{alias_name} -> #{full_name}\n" end)
      |> Shell.info_stdout()
    else
      Shell.info_stdout("no aliases set")
    end

    :ok
  end

  defp render_help do
    Shell.info_stdout("""

    `rr alias` set alias. 
    alias will be substituted when used in `rr kf <alias>

    USAGE:
      rr alias <cluster_alias> <cluster_full_name>
      rr alias --list

    FlAGS:
      --list List all the aliases currently set
    """)
  end
end
