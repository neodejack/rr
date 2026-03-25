defmodule RR.Settings do
  @moduledoc false

  alias RR.Providers.SettingsStore

  def put(key, value) do
    read()
    |> Map.put(key, value)
    |> write()
  end

  def put_in(key, value) do
    read()
    |> Kernel.put_in(key, value)
    |> write()
  end

  def get_in(key) do
    Kernel.get_in(read(), key)
  end

  def get(key) do
    Map.get(read(), key)
  end

  defp read, do: SettingsStore.read()

  defp write(config), do: SettingsStore.write(config)
end
