defmodule RR.Services.Aliases do
  @moduledoc false
  alias RR.CLI.Output
  alias RR.Settings

  def set(alias_name, full_name) do
    Settings.put_in([Access.key("alias", %{}), alias_name], full_name)
  end

  def resolve(alias_name) do
    case Settings.get_in(["alias", alias_name]) do
      nil ->
        alias_name

      full_name ->
        Output.info_stderr("resolving alias: #{alias_name} -> #{full_name} ")
        full_name
    end
  end

  def list do
    Settings.get_in(["alias"]) || %{}
  end
end
