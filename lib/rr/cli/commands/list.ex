defmodule RR.CLI.Commands.List do
  @moduledoc false
  @behaviour RR.CLI.Command

  alias __MODULE__
  alias RR.CLI.ParseError
  alias RR.Providers.Terminal
  alias RR.Services.Clusters

  defstruct []

  @impl true
  def build_action(_switches, rest) do
    if rest == [] do
      {:ok, %List{}}
    else
      {:error,
       %ParseError{
         module: List,
         message: "the subcommands you provided are invalid\nyou provided: #{Enum.join(rest, " ")}"
       }}
    end
  end

  @impl true
  def execute(%List{}) do
    with {:ok, clusters} <- Clusters.list() do
      clusters
      |> to_rows()
      |> render_table()

      :ok
    end
  end

  @impl true
  def summary, do: "list rancher clusters"

  @impl true
  def help do
    """
    list rancher clusters

    USAGE:
      rr list
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

  defp to_rows(clusters) do
    Enum.map(clusters, fn cluster -> {cluster.name, cluster.id} end)
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

    Terminal.info_stdout(Enum.join(lines, "\n"))
  end
end
