defmodule RR.Shell do
  def info(message) do
    IO.puts(IO.ANSI.format(message))
  end

  def error(message) do
    IO.puts(:stderr, message)
  end

  def raise(output) do
    error(output)
    System.halt(1)
  end
end
