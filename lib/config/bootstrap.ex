defmodule RR.Config.Bootstrap do
  @moduledoc false

  alias RR.Config.Migrator
  alias RR.Config.Schema
  alias RR.Shell

  @spec ensure_current() :: :ok | {:error, String.t()}
  def ensure_current do
    with {:ok, raw_config} <- External.Config.read_result(),
         {:ok, version} <- source_version(raw_config),
         {:ok, migrated_config} <- maybe_migrate(raw_config, version),
         :ok <- persist_if_needed(raw_config, migrated_config, version) do
      :ok
    else
      {:error, reason} ->
        {:error, "config migration failed: #{reason}"}
    end
  end

  @spec maybe_migrate(map()) :: {:ok, map()} | {:error, String.t()}
  def maybe_migrate(raw_config) when is_map(raw_config) do
    with {:ok, version} <- source_version(raw_config) do
      maybe_migrate(raw_config, version)
    end
  end

  defp source_version(raw_config) when raw_config == %{}, do: {:ok, :empty}
  defp source_version(raw_config), do: Schema.detect_version(raw_config)

  defp maybe_migrate(raw_config, :empty), do: {:ok, raw_config}

  defp maybe_migrate(raw_config, version) do
    if version == Schema.current_version() do
      {:ok, raw_config}
    else
      Migrator.migrate(raw_config, version)
    end
  end

  defp persist_if_needed(raw_config, migrated_config, _version) when raw_config == migrated_config, do: :ok
  defp persist_if_needed(_raw_config, _migrated_config, :empty), do: :ok

  defp persist_if_needed(_raw_config, migrated_config, version) do
    Shell.info_stderr("config schema #{version} detected, migrating to #{Schema.current_version()}")

    with {:ok, _backup_path} <- External.Config.backup(),
         :ok <- External.Config.write(migrated_config) do
      Shell.info_stderr("config migration complete")
      :ok
    end
  end
end
