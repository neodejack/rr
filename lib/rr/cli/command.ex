defmodule RR.CLI.Command do
  @moduledoc false

  @type parse_result(action) ::
          {:ok, action}
          | {:ok, RR.CLI.Help.t()}
          | {:error, RR.CLI.ParseError.t()}

  @doc """
  Returns the OptionParser definition RR.CLI uses to parse raw argv for this command.

  Include the standard help switch here when the command supports `--help` or `-h`.
  """
  @callback args_definition() :: keyword()

  @doc """
  Builds a typed action or parse error from already-parsed switches and positional args.

  This callback must not parse raw argv or perform side effects.
  """
  @callback build_action(keyword(), [String.t()]) :: parse_result(term())

  @doc "Executes the typed action for the command."
  @callback execute(term()) :: :ok | {:error, String.t()}

  @doc "Returns the one-line summary shown in top-level help."
  @callback summary() :: String.t()

  @doc "Returns the full help text rendered for this command."
  @callback help() :: String.t()
end
