defmodule External.Config.Impl do
  @moduledoc false
  @behaviour External.Config

  @config "config.json"
  @backup_suffix ".bak"
  @tmp_suffix ".tmp"

  @impl true
  def read do
    case read_result() do
      {:ok, term} -> term
      {:error, _reason} -> %{}
    end
  end

  @impl true
  def read_result do
    case File.read(file()) do
      {:ok, binary} ->
        case JSON.decode(binary) do
          {:ok, term} when is_map(term) ->
            {:ok, term}

          {:ok, _term} ->
            {:error, "config file must contain a JSON object"}

          {:error, reason} ->
            {:error, "config file is not valid JSON: #{inspect(reason)}"}
        end

      {:error, :enoent} ->
        {:ok, %{}}

      {:error, reason} ->
        {:error, "failed to read config file: #{:file.format_error(reason)}"}
    end
  end

  @impl true
  def backup do
    with :ok <- File.mkdir_p(home_dir()),
         :ok <- File.cp(file(), backup_file()) do
      {:ok, backup_file()}
    else
      {:error, reason} ->
        {:error, "failed to back up config file: #{:file.format_error(reason)}"}
    end
  end

  @impl true
  def write(config) do
    tmp_file = tmp_file()

    with :ok <- File.mkdir_p(home_dir()),
         :ok <- File.write(tmp_file, JSON.encode!(config)),
         :ok <- File.rename(tmp_file, file()) do
      :ok
    else
      {:error, reason} ->
        File.rm(tmp_file)
        {:error, "failed to write config file: #{:file.format_error(reason)}"}
    end
  end

  defp file do
    home_dir() |> Path.join(@config) |> Path.expand()
  end

  defp backup_file do
    file() <> @backup_suffix
  end

  defp tmp_file do
    file() <> @tmp_suffix
  end

  defp home_dir do
    RR.Config.home_dir()
  end
end
