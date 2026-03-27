defmodule RR.Providers.SettingsStore.Impl do
  @moduledoc false
  @behaviour RR.Providers.SettingsStore

  alias RR.Config.Paths

  @impl true
  def read do
    with {:ok, binary} <- File.read(file()),
         {:ok, term} <- JSON.decode(binary) do
      term
    else
      _ ->
        %{}
    end
  end

  @impl true
  def write(config) do
    with :ok <- File.mkdir_p(Paths.home_dir()) do
      File.write(Paths.settings_file(), JSON.encode!(config))
    end
  end

  defp file do
    Paths.settings_file()
  end
end
