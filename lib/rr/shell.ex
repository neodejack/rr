defmodule RR.Shell do
  @moduledoc false
  def info(message) do
    IO.puts(IO.ANSI.format(message))
  end

  def info_stderr(message) do
    IO.puts(:stderr, message)
  end

  def error(message) do
    IO.puts(:stderr, message)
  end

  def raise(output) do
    error(output)
    # TODO: we will refactor control flow so that we won't need :raise_on_error config here.
    if Application.get_env(:rr, :raise_on_error, false) do
      raise RuntimeError, message: IO.iodata_to_binary(output)
    else
      System.halt(1)
    end
  end
end
