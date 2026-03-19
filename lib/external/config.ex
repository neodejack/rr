defmodule External.Config do
  @moduledoc false
  alias __MODULE__

  @callback read() :: map()
  def read, do: impl().read()

  @callback read_result() :: {:ok, map()} | {:error, String.t()}
  def read_result, do: impl().read_result()

  @callback backup() :: {:ok, String.t()} | {:error, String.t()}
  def backup, do: impl().backup()

  @callback write(map()) :: :ok | {:error, String.t()}
  def write(config), do: impl().write(config)

  defp impl, do: Module.concat([Config, Application.get_env(:rr, :external_bound, Impl)])
end
