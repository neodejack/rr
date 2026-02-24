defmodule RR.Yo do
  @moduledoc false
  alias RR.Shell

  def run(args) do
    with :ok <- parse_args(args) do
      yo_template_path()
      |> EEx.eval_file()
      |> Shell.info()

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
    Shell.info("""
    output shell integration for rr (works with both zsh and bash)

    USAGE:
      rr yo
    """)
  end

  defp yo_template_path do
    :rr
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates/yo.eex")
  end
end
