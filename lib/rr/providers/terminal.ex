defmodule RR.Providers.Terminal do
  @moduledoc false

  @callback info_stdout(IO.ANSI.ansidata() | iodata()) :: :ok
  def info_stdout(message), do: impl().info_stdout(message)

  @callback info_stderr(iodata()) :: :ok
  def info_stderr(message), do: impl().info_stderr(message)

  @callback error(iodata()) :: :ok
  def error(message), do: impl().error(message)

  @callback input(keyword()) :: String.t()
  def input(opts), do: impl().input(opts)

  @callback confirm(keyword()) :: boolean()
  def confirm(opts), do: impl().confirm(opts)

  defp impl, do: Module.concat([__MODULE__, Application.get_env(:rr, :external_bound, Impl)])
end
