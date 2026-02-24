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
    with {switches, rest, []} <- OptionParser.parse(args, args_definition()),
         false <- Keyword.has_key?(switches, :help),
         [] <- rest do
      :ok
    else
      _ -> render_help()
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

    :ok
  end

  defp yo_template_path do
    :rr
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates/yo.eex")
  end
end
