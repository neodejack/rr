defmodule RR.CLI.Commands.Yo do
  @moduledoc false
  @behaviour RR.CLI.Command

  alias RR.CLI.ArgParser
  alias RR.CLI.Help
  alias RR.CLI.Output
  alias RR.CLI.ParseError
  alias RR.Config.Paths

  defstruct []

  @impl true
  def parse(args) do
    with {:ok, switches, rest} <- ArgParser.parse(args, args_definition(), __MODULE__) do
      cond do
        Keyword.has_key?(switches, :help) ->
          {:ok, %Help{module: __MODULE__}}

        rest != [] ->
          {:error,
           %ParseError{
             module: __MODULE__,
             message: "rr yo command doesn't take any args\nyou provided: #{Enum.join(rest, " ")}"
           }}

        true ->
          {:ok, %__MODULE__{}}
      end
    end
  end

  @impl true
  def execute(%__MODULE__{}) do
    Paths.yo_template_path()
    |> EEx.eval_file()
    |> Output.info_stdout()

    :ok
  end

  @impl true
  def summary, do: "output shell integration (zsh/bash)"

  @impl true
  def help do
    """
    output shell integration for rr (works with both zsh and bash)

    USAGE:
      rr yo
    """
  end

  defp args_definition do
    [
      strict: [
        help: :boolean
      ],
      alias: [h: :help]
    ]
  end
end
