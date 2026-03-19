defmodule RR.Config.Schema do
  @moduledoc false

  @schema_version_key "schema_version"
  @profiles_key "profiles"
  @current_version 1

  @spec current_version() :: non_neg_integer()
  def current_version, do: @current_version

  @spec empty_state() :: map()
  def empty_state do
    %{
      @schema_version_key => @current_version,
      @profiles_key => %{}
    }
  end

  @spec detect_version(map()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def detect_version(config) when is_map(config) do
    case Map.get(config, @schema_version_key) do
      nil ->
        {:ok, 0}

      version when is_integer(version) and version >= 0 and version <= @current_version ->
        {:ok, version}

      version when is_integer(version) and version > @current_version ->
        {:error, "config schema #{version} is newer than this rr release supports"}

      _version ->
        {:error, "config schema_version must be a non-negative integer"}
    end
  end

  def detect_version(_config), do: {:error, "config file must contain a JSON object"}

  @spec current?(map()) :: boolean()
  def current?(config), do: detect_version(config) == {:ok, @current_version}
end
