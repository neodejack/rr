defmodule RR.CLI.Commands.YoTest do
  use ExUnit.Case, async: true

  alias RR.CLI
  alias RR.CLI.Commands.Yo
  alias RR.CLI.ParseError
  alias RR.Providers.Terminal.Mock, as: TerminalMock

  setup do
    TerminalMock.reset()
  end

  describe "build_action/2" do
    test "returns an action for empty positional args" do
      assert {:ok, %Yo{}} = Yo.build_action([], [])
    end

    test "centralizes help through RR.CLI.parse/1" do
      assert {:ok, %RR.CLI.Help{module: Yo}} = CLI.parse(["yo", "--help"])
    end

    test "rejects unexpected positional args" do
      assert {:error, %ParseError{module: Yo, message: message}} = Yo.build_action([], ["extra"])

      assert message =~ "doesn't take any args"
      assert message =~ "extra"
    end
  end

  test "prints shell integration snippet" do
    assert :ok = Yo.execute(%Yo{})

    assert TerminalMock.stdout() =~ "yo()"
    assert TerminalMock.stdout() =~ "rr kf --sh"
  end
end
