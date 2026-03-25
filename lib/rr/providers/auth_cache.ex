defmodule RR.Providers.AuthCache do
  @moduledoc false

  @callback get(key :: term()) :: {:hit, boolean()} | :miss
  def get(key), do: impl().get(key)

  @callback put(key :: term(), valid? :: boolean()) :: :ok
  def put(key, valid?), do: impl().put(key, valid?)

  @callback clear() :: :ok
  def clear, do: impl().clear()

  defp impl, do: Module.concat([__MODULE__, Application.get_env(:rr, :external_bound, ETS)])
end
