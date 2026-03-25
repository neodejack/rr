defmodule RR.CLI.Commands.YoTest do
  use ExUnit.Case, async: true

  alias RR.CLI.Commands.Yo

  test "prints shell integration snippet" do
    output = ExUnit.CaptureIO.capture_io(fn -> Yo.run([]) end)

    assert output =~ "yo()"
    assert output =~ "rr kf --sh"
  end
end
