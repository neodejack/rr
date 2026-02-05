defmodule External.Config.Impl do
  @moduledoc false
  @behaviour External.Config

  @config "config.json"

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
    if not File.dir?(home_dir()) do
      File.mkdir_p!(home_dir())
    end

    File.write!(file(), JSON.encode!(config))
  end

  defp file do
    home_dir() |> Path.join(@config) |> Path.expand()
  end

  defp home_dir do
    RR.Config.home_dir()
  end
end
