defmodule RR.Config.AuthTest do
  use ExUnit.Case, async: false

  import Mox

  alias RR.Providers.AuthCache.Mock, as: AuthCacheMock
  alias RR.Providers.Rancher.Mock, as: RancherMock
  alias RR.Providers.SettingsStore.Mock, as: SettingsStoreMock
  alias RR.Services.Auth
  alias RR.Settings

  setup :verify_on_exit!

  setup do
    store = start_supervised!({Agent, fn -> %{} end}, id: make_ref())
    cache = start_supervised!({Agent, fn -> %{} end}, id: make_ref())

    stub(SettingsStoreMock, :read, fn ->
      Agent.get(store, & &1)
    end)

    stub(SettingsStoreMock, :write, fn config ->
      Agent.update(store, fn _ -> config end)
      :ok
    end)

    stub(AuthCacheMock, :get, fn key ->
      Agent.get(cache, fn entries ->
        case Map.fetch(entries, key) do
          {:ok, valid?} -> {:hit, valid?}
          :error -> :miss
        end
      end)
    end)

    stub(AuthCacheMock, :put, fn key, valid? ->
      Agent.update(cache, &Map.put(&1, key, valid?))
      :ok
    end)

    Settings.put("rancher_hostname", "https://rancher.example")
    Settings.put("rancher_token", "token-123:abc")

    :ok
  end

  describe "ensure_valid_auth/0" do
    test "internet connection error" do
      expect(RancherMock, :get_token_info, fn _ ->
        {:error, :unknown, inspect(%Req.TransportError{reason: :nxdomain})}
      end)

      assert {:error, :unknown, reason} = Auth.ensure_valid_auth()
      assert reason =~ "nxdomain"
    end

    test "uses cached auth to avoid re-validating the token" do
      expect(RancherMock, :get_token_info, 1, fn _ ->
        valid_token_info()
      end)

      assert {:ok, _} = Auth.ensure_valid_auth()
      assert {:ok, _} = Auth.ensure_valid_auth()
    end
  end

  defp valid_token_info do
    now_ms = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok,
     %{
       description: "foo",
       expired: false,
       enabled: true,
       created_ts: now_ms - 300_000,
       ttl: 864_000_000
     }}
  end
end
