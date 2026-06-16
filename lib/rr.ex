defmodule RR do
  @moduledoc false

  alias RR.Providers.Terminal

  def main do
    code =
      try do
        case RR.CLI.run(Burrito.Util.Args.argv()) do
          :ok ->
            0

          {:error, msg} ->
            Terminal.error(msg)
            1
        end
      rescue
        e ->
          Terminal.error(Exception.message(e))
          1
      end

    System.halt(code)
  end
end
