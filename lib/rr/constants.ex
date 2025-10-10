defmodule RR.Constants do
  @moduledoc false

  @cli_name :rr

  def cli_name, do: @cli_name
  def cli_name_string, do: Atom.to_string(@cli_name)
end
