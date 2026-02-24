defmodule RR.YoTest do
  use ExUnit.Case, async: true

  alias RR.Yo

  test "prints shell integration snippet" do
    output = ExUnit.CaptureIO.capture_io(fn -> Yo.run([]) end)

    assert output =~ "yo()"
    assert output =~ "rr kf --sh"
  end
end
