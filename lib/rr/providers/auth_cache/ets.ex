defmodule RR.Providers.AuthCache.ETS do
  @moduledoc false
  @behaviour RR.Providers.AuthCache

  @auth_cache_table :rr_auth_cache

  @impl true
  def get(key) do
    ensure_auth_cache_table()

    case :ets.lookup(@auth_cache_table, key) do
      [{^key, valid?}] when is_boolean(valid?) -> {:hit, valid?}
      _ -> :miss
    end
  end

  @impl true
  def put(key, valid?) when is_boolean(valid?) do
    ensure_auth_cache_table()
    :ets.insert(@auth_cache_table, {key, valid?})
    :ok
  end

  @impl true
  def clear do
    case :ets.whereis(@auth_cache_table) do
      :undefined -> :ok
      tid -> :ets.delete(tid)
    end

    :ok
  end

  defp ensure_auth_cache_table do
    case :ets.whereis(@auth_cache_table) do
      :undefined ->
        try do
          :ets.new(@auth_cache_table, [:named_table, :set, :public, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end

    :ok
  end
end
