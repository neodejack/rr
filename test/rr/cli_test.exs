defmodule RR.CLITest do
  use ExUnit.Case, async: true

  alias RR.CLI
  alias RR.CLI.Commands.List
  alias RR.CLI.HelpAction
  alias RR.CLI.Invocation
  alias RR.CLI.ParseError
  alias RR.Providers.Terminal.Mock, as: TerminalMock

  setup do
    TerminalMock.reset()
  end

  describe "parse/1" do
    test "returns root help for empty argv" do
      assert {:ok, %Invocation{module: CLI, action: %HelpAction{module: nil}}} = CLI.parse([])
    end

    test "returns command help from the central dispatcher" do
      assert {:ok, %Invocation{module: CLI, action: %HelpAction{module: List}}} =
               CLI.parse(["list", "--help"])
    end

    test "returns invocation for command action" do
      assert {:ok, %Invocation{module: List, action: %List{}}} = CLI.parse(["list"])
    end

    test "returns parse error for unknown command" do
      assert {:error, %ParseError{module: nil, message: "no such commands unknown"}} =
               CLI.parse(["unknown"])
    end
  end

  describe "run/1" do
    test "renders command help from the central dispatcher" do
      assert :ok = CLI.run(["list", "--help"])

      assert TerminalMock.stdout() =~ "list rancher clusters"
      assert TerminalMock.stdout() =~ "rr list"
    end

    test "renders command help before returning parse errors" do
      assert {:error, message} = CLI.run(["list", "unexpected"])
      assert message =~ "the subcommands you provided are invalid"

      assert TerminalMock.stdout() =~ "list rancher clusters"
    end

    test "renders version from the central dispatcher" do
      assert :ok = CLI.run(["--version"])

      assert TerminalMock.stdout() =~ to_string(Application.spec(:rr)[:vsn])
    end
  end
end
