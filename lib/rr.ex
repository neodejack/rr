defmodule RR do
  @moduledoc false

  alias RR.CLI.Output

  def main do
    code =
      try do
        case RR.CLI.run(Burrito.Util.Args.argv()) do
          :ok ->
            0

          {:error, msg} ->
            Output.error(msg)
            1
        end
      rescue
        e ->
          Output.error(Exception.message(e))
          1
      end

    System.halt(code)
  end
end
