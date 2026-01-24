defmodule RR.ZshTest do
  use ExUnit.Case, async: true

  alias RR.Zsh

  test "prints zsh integration snippet" do
    output = ExUnit.CaptureIO.capture_io(fn -> Zsh.run([]) end)

    assert output =~ "yo()"
    assert output =~ "rr kf --sh"
  end
end
