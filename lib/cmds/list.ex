defmodule RR.List do
  @moduledoc false
  alias External.RancherHttpClient
  alias RR.Shell

  def run(args) do
    with :ok <- parse_args(args),
         {:ok, clusters} <- RancherHttpClient.get_clusters() do
      clusters
      |> to_rows()
      |> render_table()

      :ok
    end
  end

  defp parse_args(args) do
    {switches, rest, invalid_args} = OptionParser.parse(args, args_definition())

    cond do
      invalid_args != [] ->
        invalids = Enum.map(invalid_args, fn {arg, _value} -> arg end)
        render_help()
        {:error, ["the arguments you provided are invalid:\nyou provided: #{Enum.join(invalids, " ")}"]}

      Keyword.has_key?(switches, :help) ->
        render_help()
        :ok

      rest != [] ->
        render_help()
        {:error, "the subcommands you provided are invalid\nyou provided: #{Enum.join(rest, " ")}"}

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
    Shell.info_stdout("""
    list rancher clusters

    USAGE:
      rr list
    """)
  end

  defp to_rows(clusters) do
    Enum.map(clusters, fn cluster -> {cluster["name"], cluster["id"]} end)
  end

  defp render_table(rows) do
    name_width =
      rows
      |> Enum.map(fn {name, _id} -> String.length(name) end)
      |> Enum.concat([String.length("NAME")])
      |> Enum.max()

    header = "#{String.pad_trailing("NAME", name_width)}  ID"
    separator = "#{String.duplicate("-", name_width)}  --"

    lines =
      case rows do
        [] ->
          [header, separator, "no clusters found"]

        _ ->
          data =
            Enum.map(rows, fn {name, id} ->
              "#{String.pad_trailing(name, name_width)}  #{id}"
            end)

          [header, separator | data]
      end

    Shell.info_stdout(Enum.join(lines, "\n"))
  end
end
