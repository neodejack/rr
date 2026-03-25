defmodule RR.CLI.ParseError do
  @moduledoc false

  @enforce_keys [:message]
  defstruct [:message, :module, exit_code: 1]

  @type t :: %__MODULE__{
          message: String.t() | IO.chardata(),
          module: module() | nil,
          exit_code: pos_integer()
        }
end
