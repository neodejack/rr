defmodule RR.CLI.Commands.ListTest do
  use ExUnit.Case, async: true

  import Mox

  alias RR.CLI.Commands.List
  alias RR.CLI.Help
  alias RR.CLI.ParseError
  alias RR.Providers.AuthCache.Mock, as: AuthCacheMock
  alias RR.Providers.Rancher.Mock, as: RancherMock
  alias RR.Providers.SettingsStore.Mock, as: SettingsStoreMock
  alias RR.Settings

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

    Settings.put("rancher_hostname", "https://rancher.example")
    Settings.put("rancher_token", "token-123:abc")
    :ok
  end

  describe "parse/1" do
    test "returns an action for empty argv" do
      assert {:ok, %List{}} = List.parse([])
    end

    test "returns help for --help" do
      assert {:ok, %Help{module: List}} = List.parse(["--help"])
    end

    test "rejects unexpected positional args" do
      assert {:error, %ParseError{module: List, message: message}} = List.parse(["unexpected"])
      assert message =~ "subcommands you provided are invalid"
      assert message =~ "unexpected"
    end
  end

  describe "execute/1" do
    test "renders a table of cluster names and ids" do
      clusters = [
        %{"id" => "c-1", "name" => "dev"},
        %{"id" => "c-9999", "name" => "production"}
      ]

      expect(RancherMock, :get_clusters, fn _auth ->
        {:ok, clusters}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.execute(%List{}) end)

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

      output = ExUnit.CaptureIO.capture_io(fn -> List.execute(%List{}) end)

      assert output =~ "NAME"
      assert output =~ "no clusters found"
    end
  end
end
