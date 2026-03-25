defmodule RR.CLI.Commands.Yo do
  @moduledoc false
  alias RR.CLI.Output
  alias RR.Config.Paths

  def run(args) do
    with :ok <- parse_args(args) do
      Paths.yo_template_path()
      |> EEx.eval_file()
      |> Output.info_stdout()

      :ok
    end
  end

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, ["the arguments you provided are invalid: ", invalids]}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      rest != [] ->
        render_help()
        {:error, "rr yo command doesn't take any args\nyou provided: #{Enum.join(rest, " ")}"}

      true ->
        :ok
    end
  end

  defp args_definition do
    [
      strict: [
        help: :boolean
      ],
      alias: [h: :help]
    ]
  end

  defp render_help do
    Output.info_stdout("""
    output shell integration for rr (works with both zsh and bash)

    USAGE:
      rr yo
    """)
  end
end
