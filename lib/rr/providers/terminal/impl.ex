defmodule RR.Providers.Terminal.Impl do
  @moduledoc false
  @behaviour RR.Providers.Terminal

  @impl true
  def info_stdout(message) do
    IO.puts(IO.ANSI.format(message))
  end

  @impl true
  def info_stderr(message) do
    IO.puts(:stderr, message)
  end

  @impl true
  def error(message) do
    IO.puts(:stderr, message)
  end

  @impl true
  def input(opts) do
    Owl.IO.input(opts)
  end

  @impl true
  def confirm(opts) do
    Owl.IO.confirm(opts)
  end
end
