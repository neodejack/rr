defmodule RR.CLI.Command do
  @moduledoc false

  @type parse_result(action) ::
          {:ok, action}
          | {:ok, RR.CLI.Help.t()}
          | {:error, RR.CLI.ParseError.t()}

  @callback parse([String.t()]) :: parse_result(term())
  @callback execute(term()) :: :ok | {:error, String.t()}
  @callback summary() :: String.t()
  @callback help() :: String.t()
end
