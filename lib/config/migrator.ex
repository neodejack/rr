defmodule RR.Config.Migrator do
  @moduledoc false

  alias RR.Config.Migrations.V0ToCurrent
  alias RR.Config.Schema

  @spec migrate(map(), non_neg_integer()) :: {:ok, map()} | {:error, String.t()}
  def migrate(config, version) do
    cond do
      version == Schema.current_version() ->
        {:ok, config}

      version == 0 ->
        V0ToCurrent.migrate(config, Schema.current_version())

      true ->
        {:error, "no config migration is available for schema #{version}"}
    end
  end
end
