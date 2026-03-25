defmodule RR.CLI.Commands.YoTest do
  use ExUnit.Case, async: true

  alias RR.CLI.Commands.Yo
  alias RR.CLI.Help
  alias RR.CLI.ParseError

  describe "parse/1" do
    test "returns an action for empty argv" do
      assert {:ok, %Yo{}} = Yo.parse([])
    end

    test "returns help for --help" do
      assert {:ok, %Help{module: Yo}} = Yo.parse(["--help"])
    end

    test "rejects unexpected positional args" do
      assert {:error, %ParseError{module: Yo, message: message}} = Yo.parse(["extra"])
      assert message =~ "doesn't take any args"
      assert message =~ "extra"
    end
  end

  test "prints shell integration snippet" do
    output = ExUnit.CaptureIO.capture_io(fn -> Yo.run([]) end)

    assert output =~ "yo()"
    assert output =~ "rr kf --sh"
  end
end
