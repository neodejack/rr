defmodule RR.CLI.Commands.AliasTest do
  use ExUnit.Case, async: true

  import Mox

  alias RR.CLI.Commands.Alias
  alias RR.CLI.Commands.Alias.ListAction
  alias RR.CLI.Commands.Alias.SetAction
  alias RR.CLI.Help
  alias RR.CLI.ParseError
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

    :ok
  end

  describe "parse/1" do
    test "returns list action for --list" do
      assert {:ok, %ListAction{}} = Alias.parse(["--list"])
    end

    test "returns set action for alias pair" do
      assert {:ok, %SetAction{alias_name: "prod", full_name: "production"}} =
               Alias.parse(["prod", "production"])
    end

    test "returns help for --help" do
      assert {:ok, %Help{module: Alias}} = Alias.parse(["--help"])
    end

    test "rejects --list with positional args" do
      assert {:error, %ParseError{module: Alias, message: message}} =
               Alias.parse(["--list", "extra"])

      assert message =~ "--list does not take positional args"
      assert message =~ "extra"
    end
  end

  describe "execute/1" do
    test "writes an alias for set action" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = Alias.execute(%SetAction{alias_name: "prod", full_name: "production"})
        end)

      assert output =~ "alias: prod -> production"
      assert Settings.get_in(["alias", "prod"]) == "production"
    end

    test "renders alias list for list action" do
      Settings.put_in([Access.key("alias", %{}), "prod"], "production")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = Alias.execute(%ListAction{})
        end)

      assert output =~ "these aliases are found"
      assert output =~ "prod -> production"
    end
  end
end
