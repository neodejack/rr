defmodule External.Config do
  @moduledoc false
  alias __MODULE__

  @callback read() :: map()
  def read, do: impl().read()

  ## FIX: the callback signature is not accurate
  @callback write(map()) :: :ok
  def write(config), do: impl().write(config)

  defp impl, do: Module.concat([Config, Application.get_env(:rr, :external_bound, Impl)])
end
