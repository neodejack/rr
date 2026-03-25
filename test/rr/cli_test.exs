defmodule RR.CLITest do
  use ExUnit.Case, async: true

  alias RR.CLI
  alias RR.CLI.Commands.List
  alias RR.CLI.Help
  alias RR.CLI.Invocation
  alias RR.CLI.ParseError

  describe "parse/1" do
    test "returns root help for empty argv" do
      assert {:ok, %Help{module: nil}} = CLI.parse([])
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
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = CLI.run(["list", "--help"])
        end)

      assert output =~ "list rancher clusters"
      assert output =~ "rr list"
    end

    test "renders command help before returning parse errors" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert {:error, message} = CLI.run(["list", "unexpected"])
          assert message =~ "the subcommands you provided are invalid"
        end)

      assert output =~ "list rancher clusters"
    end

    test "renders version from the central dispatcher" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = CLI.run(["--version"])
        end)

      assert output =~ to_string(Application.spec(:rr)[:vsn])
    end
  end
end
