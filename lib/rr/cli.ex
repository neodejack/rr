defmodule RR.CLI do
  @moduledoc false
  alias RR.CLI.Commands.Alias
  alias RR.CLI.Commands.Kf
  alias RR.CLI.Commands.List
  alias RR.CLI.Commands.Login
  alias RR.CLI.Commands.Yo
  alias RR.CLI.Help
  alias RR.CLI.Invocation
  alias RR.CLI.Output
  alias RR.CLI.ParseError

  defmodule VersionAction do
    @moduledoc false
    defstruct []
  end

  @commands %{
    "login" => Login,
    "alias" => Alias,
    "kf" => Kf,
    "list" => List,
    "yo" => Yo
  }

  def run(argv) do
    case parse(argv) do
      {:ok, %Help{} = help} ->
        render_help(help)

      {:ok, %Invocation{module: __MODULE__, action: %VersionAction{}}} ->
        render_version()

      {:ok, %Invocation{module: module, action: action}} ->
        module.execute(action)

      {:error, %ParseError{} = error} ->
        render_parse_error(error)
    end
  end

  def parse(argv) do
    case argv do
      [] ->
        {:ok, %Help{module: nil}}

      [flag | _] when flag in ["--help", "-h"] ->
        {:ok, %Help{module: nil}}

      [flag | _] when flag in ["--version", "-v"] ->
        {:ok, %Invocation{module: __MODULE__, action: %VersionAction{}}}

      [cmd | args] ->
        case Map.fetch(@commands, cmd) do
          {:ok, module} ->
            parse_command(module, args)

          :error ->
            {:error, %ParseError{message: "no such commands #{cmd}", module: nil}}
        end
    end
  end

  defp parse_command(module, args) do
    case module.parse(args) do
      {:ok, %Help{} = help} ->
        {:ok, help}

      {:ok, action} ->
        {:ok, %Invocation{module: module, action: action}}

      {:error, %ParseError{} = error} ->
        {:error, error}
    end
  end

  defp render_version do
    Output.info_stdout(Application.spec(:rr)[:vsn])
    :ok
  end

  defp render_help(%Help{module: nil}) do
    Output.info_stdout("""
    playing with rancher generated kubeconfigs

    COMMANDS
      login     : #{Login.summary()}
      alias     : #{Alias.summary()}
      kf        : #{Kf.summary()}
      list      : #{List.summary()}
      yo        : #{Yo.summary()}
    """)

    Output.info_stdout(["current version: ", Application.spec(:rr)[:vsn]])
    :ok
  end

  defp render_help(%Help{module: module}) do
    Output.info_stdout(module.help())
    :ok
  end

  defp render_parse_error(%ParseError{module: module, message: message}) when not is_nil(module) do
    Output.info_stdout(module.help())
    {:error, message}
  end

  defp render_parse_error(%ParseError{message: message}) do
    {:error, message}
  end
end
