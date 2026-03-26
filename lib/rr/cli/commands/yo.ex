defmodule RR.CLI.Commands.Yo do
  @moduledoc false
  @behaviour RR.CLI.Command

  alias RR.CLI.Output
  alias RR.CLI.ParseError
  alias RR.Config.Paths

  defstruct []

  @impl true
  def build_action(_switches, rest) do
    if rest == [] do
      {:ok, %__MODULE__{}}
    else
      {:error,
       %ParseError{
         module: __MODULE__,
         message: "rr yo command doesn't take any args\nyou provided: #{Enum.join(rest, " ")}"
       }}
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

  @impl true
  def args_definition do
    [
      strict: [
        help: :boolean
      ],
      alias: [h: :help]
    ]
  end
end
