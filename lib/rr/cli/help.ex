defmodule RR.CLI.Help do
  @moduledoc false

  @enforce_keys [:module]
  defstruct [:module]

  @type t :: %__MODULE__{module: module() | nil}
end
