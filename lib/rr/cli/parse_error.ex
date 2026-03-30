defmodule RR.CLI.ParseError do
  @moduledoc false

  alias __MODULE__

  @enforce_keys [:message]
  defstruct [:message, :module, exit_code: 1]

  @type t :: %ParseError{
          message: String.t() | IO.chardata(),
          module: module() | nil,
          exit_code: pos_integer()
        }
end
