defmodule RR.CLI.Invocation do
  @moduledoc false

  @enforce_keys [:module, :action]
  defstruct [:module, :action]

  @type t :: %__MODULE__{module: module(), action: struct()}
end
