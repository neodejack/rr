defmodule RR.CLI do
  @moduledoc false
  alias __MODULE__
  alias RR.CLI.ArgParser
  alias RR.CLI.Commands.Alias
  alias RR.CLI.Commands.Kf
  alias RR.CLI.Commands.List
  alias RR.CLI.Commands.Login
  alias RR.CLI.Commands.Yo
  alias RR.CLI.Invocation
  alias RR.CLI.ParseError
  alias RR.Providers.Terminal

  defmodule HelpAction do
    @moduledoc false
    @enforce_keys [:module]
    defstruct [:module]
  end

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
      {:ok, %Invocation{module: module, action: action}} ->
        module.execute(action)

      {:error, %ParseError{} = error} ->
        render_parse_error(error)
    end
  end

  def parse(argv) do
    case argv do
      [] ->
        {:ok, %Invocation{module: CLI, action: %HelpAction{module: nil}}}

      [flag | _] when flag in ["--help", "-h"] ->
        {:ok, %Invocation{module: CLI, action: %HelpAction{module: nil}}}

      [flag | _] when flag in ["--version", "-v"] ->
        {:ok, %Invocation{module: CLI, action: %VersionAction{}}}

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
    with {:ok, switches, rest} <- ArgParser.parse(args, module.args_definition(), module) do
      if Keyword.has_key?(switches, :help) do
        {:ok, %Invocation{module: CLI, action: %HelpAction{module: module}}}
      else
        normalize_command_result(module, module.build_action(switches, rest))
      end
    end
  end

  defp normalize_command_result(module, {:ok, action}), do: {:ok, %Invocation{module: module, action: action}}
  defp normalize_command_result(_module, {:error, %ParseError{} = error}), do: {:error, error}

  defp normalize_command_result(module, other) do
    raise ArgumentError,
          "expected #{inspect(module)}.build_action/2 to return {:ok, action} or {:error, %RR.CLI.ParseError{}}, got: #{inspect(other)}"
  end

  def execute(%HelpAction{module: nil}) do
    Terminal.info_stdout("""
    playing with rancher generated kubeconfigs

    COMMANDS
    #{Enum.map_join(@commands, "\n  ", fn {name, mod} -> "  #{String.pad_trailing(name, 10)}: #{mod.summary()}" end)}
    """)

    Terminal.info_stdout(["current version: ", Application.spec(:rr)[:vsn]])
    :ok
  end

  def execute(%HelpAction{module: module}) do
    Terminal.info_stdout(module.help())
    :ok
  end

  def execute(%VersionAction{}) do
    Terminal.info_stdout(Application.spec(:rr)[:vsn])
    :ok
  end

  defp render_parse_error(%ParseError{module: module, message: message}) when not is_nil(module) do
    Terminal.info_stdout(module.help())
    {:error, message}
  end

  defp render_parse_error(%ParseError{message: message}) do
    {:error, message}
  end
end
