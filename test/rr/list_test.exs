defmodule RR.ListTest do
  use ExUnit.Case, async: true

  import Mox

  alias RR.Config
  alias RR.List
  alias RR.Providers.AuthCache.Mock, as: AuthCacheMock
  alias RR.Providers.Rancher.Mock, as: RancherMock
  alias RR.Providers.SettingsStore.Mock, as: SettingsStoreMock

  setup :verify_on_exit!

  setup do
    store = start_supervised!({Agent, fn -> %{} end}, id: make_ref())

    stub(SettingsStoreMock, :read, fn ->
      Agent.get(store, & &1)
    end)

    stub(SettingsStoreMock, :write, fn config ->
      Agent.update(store, fn _ -> config end)
      :ok
    end)

    stub(AuthCacheMock, :get, fn _key -> {:hit, true} end)
    stub(AuthCacheMock, :put, fn _key, _valid? -> :ok end)
    stub(AuthCacheMock, :clear, fn -> :ok end)

    Config.put_auth({"https://rancher.example", "token-123:abc"})
    :ok
  end

  describe "run/1" do
    test "renders a table of cluster names and ids" do
      clusters = [
        %{"id" => "c-1", "name" => "dev"},
        %{"id" => "c-9999", "name" => "production"}
      ]

      expect(RancherMock, :get_clusters, fn _auth ->
        {:ok, clusters}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run([]) end)

      assert output =~ "NAME"
      assert output =~ "ID"
      assert output =~ "dev"
      assert output =~ "production"
      assert output =~ "c-1"
      assert output =~ "c-9999"
    end

    test "renders empty state when no clusters returned" do
      expect(RancherMock, :get_clusters, fn _auth ->
        {:ok, []}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run([]) end)

      assert output =~ "NAME"
      assert output =~ "no clusters found"
    end
  end
end
