defmodule RR.CLI.Commands.ListTest do
  use ExUnit.Case, async: true

  import Mox

  alias RR.CLI
  alias RR.CLI.Commands.List
  alias RR.CLI.ParseError
  alias RR.Providers.AuthCache.Mock, as: AuthCacheMock
  alias RR.Providers.Rancher.Mock, as: RancherMock
  alias RR.Providers.SettingsStore.Mock, as: SettingsStoreMock
  alias RR.Providers.Terminal.Mock, as: TerminalMock
  alias RR.Settings

  setup :verify_on_exit!

  setup do
    TerminalMock.reset()
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

  describe "build_action/2" do
    test "returns an action for empty positional args" do
      assert {:ok, %List{}} = List.build_action([], [])
    end

    test "centralizes help through RR.CLI.parse/1" do
      assert {:ok, %RR.CLI.Help{module: List}} = CLI.parse(["list", "--help"])
    end

    test "rejects unexpected positional args" do
      assert {:error, %ParseError{module: List, message: message}} =
               List.build_action([], ["unexpected"])

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

      assert :ok = List.execute(%List{})

      assert TerminalMock.stdout() =~ "NAME"
      assert TerminalMock.stdout() =~ "ID"
      assert TerminalMock.stdout() =~ "dev"
      assert TerminalMock.stdout() =~ "production"
      assert TerminalMock.stdout() =~ "c-1"
      assert TerminalMock.stdout() =~ "c-9999"
    end

    test "renders empty state when no clusters returned" do
      expect(RancherMock, :get_clusters, fn _auth ->
        {:ok, []}
      end)

      assert :ok = List.execute(%List{})

      assert TerminalMock.stdout() =~ "NAME"
      assert TerminalMock.stdout() =~ "no clusters found"
    end
  end
end
