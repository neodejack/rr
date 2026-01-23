defmodule RR.List do
  @moduledoc false
  alias External.RancherHttpClient
  alias RR.Shell

  def run(args) do
    parse_args!(args)

    case RancherHttpClient.get_clusters() do
      {:ok, clusters} ->
        clusters
        |> to_rows()
        |> render_table()

      {:error, err_msg} ->
        Shell.raise(err_msg)
    end
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
    list rancher clusters

    USAGE:
      rr list
    """)

    System.halt(0)
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

    Shell.info(Enum.join(lines, "\n"))
  end
end
