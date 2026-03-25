defmodule RR.CLI.ArgParser do
  @moduledoc false

  alias RR.CLI.ParseError

  @spec parse([String.t()], keyword(), module()) ::
          {:ok, keyword(), [String.t()]} | {:error, ParseError.t()}
  def parse(argv, option_spec, command_module) do
    case OptionParser.parse(argv, option_spec) do
      {switches, rest, []} ->
        {:ok, switches, rest}

      {_switches, _rest, invalid_args} ->
        invalids = Enum.map_join(invalid_args, " ", fn {arg, _value} -> arg end)

        {:error,
         %ParseError{
           module: command_module,
           message: "the arguments you provided are invalid:\nyou provided: #{invalids}"
         }}
    end
  end
end
