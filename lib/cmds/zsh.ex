defmodule RR.Zsh do
  @moduledoc false
  alias RR.Shell

  def run(args) do
    parse_args!(args)

    zsh_template_path()
    |> EEx.eval_file()
    |> Shell.info()
  end

  defp parse_args!(args) do
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
    output zsh integration for rr

    USAGE:
      rr zsh
    """)

    System.halt(0)
  end

  defp zsh_template_path do
    :rr
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates/zsh_integration.eex")
  end
end
