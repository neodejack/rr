defmodule RR.CLI.Commands.Alias do
  @moduledoc false
  @behaviour RR.CLI.Command

  alias RR.CLI.Output
  alias RR.CLI.ParseError
  alias RR.Services.Aliases

  defmodule ListAction do
    @moduledoc false
    defstruct []
  end

  defmodule SetAction do
    @moduledoc false

    @enforce_keys [:alias_name, :full_name]
    defstruct [:alias_name, :full_name]
  end

  def resolve(alias) do
    Aliases.resolve(alias)
  end

  @impl true
  def build_action(switches, rest) do
    cond do
      Keyword.has_key?(switches, :list) and rest == [] ->
        {:ok, %ListAction{}}

      Keyword.has_key?(switches, :list) ->
        {:error,
         %ParseError{
           module: __MODULE__,
           message: "--list does not take positional args\nyou provided: #{Enum.join(rest, " ")}"
         }}

      match?([_, _], rest) ->
        [alias_name, full_name] = rest
        {:ok, %SetAction{alias_name: alias_name, full_name: full_name}}

      true ->
        {:error,
         %ParseError{
           module: __MODULE__,
           message: "you didn't provide valid <cluster_alias> and <cluster_full_name>"
         }}
    end
  end

  @impl true
  def execute(%ListAction{}) do
    aliases = Aliases.list()

    if map_size(aliases) > 0 do
      Output.info_stdout("these aliases are found:\n")

      aliases
      |> Enum.map(fn {alias_name, full_name} -> "  #{alias_name} -> #{full_name}\n" end)
      |> Output.info_stdout()
    else
      Output.info_stdout("no aliases set")
    end

    :ok
  end

  def execute(%SetAction{alias_name: alias_name, full_name: full_name}) do
    Aliases.set(alias_name, full_name)
    Output.info_stdout("alias: #{alias_name} -> #{full_name} ")
    :ok
  end

  @impl true
  def summary, do: "set cluster aliases"

  @impl true
  def help do
    """

    `rr alias` set alias.
    alias will be substituted when used in `rr kf <alias>

    USAGE:
      rr alias <cluster_alias> <cluster_full_name>
      rr alias --list

    FlAGS:
      --list List all the aliases currently set
    """
  end

  @impl true
  def args_definition do
    [
      strict: [
        help: :boolean,
        list: :boolean
      ],
      alias: [h: :help]
    ]
  end
end
