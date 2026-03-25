defmodule RR.Providers.SettingsStore do
  @moduledoc false

  @callback read() :: map()
  def read, do: impl().read()

  @callback write(map()) :: :ok | {:error, term()}
  def write(config), do: impl().write(config)

  defp impl, do: Module.concat([__MODULE__, Application.get_env(:rr, :external_bound, File)])
end
