defmodule RR.CLI.Commands.Yo do
  @moduledoc false
  @behaviour RR.CLI.Command

  alias __MODULE__
  alias RR.CLI.ParseError
  alias RR.Config.Paths
  alias RR.Providers.Terminal

  defstruct []

  @impl true
  def build_action(_switches, rest) do
    if rest == [] do
      {:ok, %Yo{}}
    else
      {:error,
       %ParseError{
         module: Yo,
         message: "rr yo command doesn't take any args\nyou provided: #{Enum.join(rest, " ")}"
       }}
    end
  end

  @impl true
  def execute(%Yo{}) do
    Paths.yo_template_path()
    |> EEx.eval_file()
    |> Terminal.info_stdout()

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
