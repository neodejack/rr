defmodule External.Config do
  @moduledoc false
  use External

  defcallback(read() :: map())
  defcallback(write(map()) :: :ok)
end
