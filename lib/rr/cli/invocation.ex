defmodule RR.CLI.Invocation do
  @moduledoc false

  alias __MODULE__

  @enforce_keys [:module, :action]
  defstruct [:module, :action]

  @type t :: %Invocation{module: module(), action: struct()}
end
