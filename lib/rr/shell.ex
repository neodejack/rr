defmodule RR.Shell do
  @moduledoc false
  def info_stdout(message) do
    IO.puts(IO.ANSI.format(message))
  end

  def info_stderr(message) do
    IO.puts(:stderr, message)
  end

  def error(message) do
    IO.puts(:stderr, message)
  end
end
