defmodule RR.Config.Paths do
  @moduledoc false

  @config "config.json"

  def home_dir do
    override_dir = System.get_env("RR_HOME")

    if override_dir == nil or override_dir == "" do
      Path.expand("~/.rr")
    else
      Path.expand(override_dir)
    end
  end

  def kubeconfig_dir do
    Path.join(home_dir(), "kubeconfigs")
  end

  def settings_file do
    home_dir() |> Path.join(@config) |> Path.expand()
  end

  def sh_template_path do
    :rr
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates/sh.eex")
  end

  def yo_template_path do
    :rr
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates/yo.eex")
  end
end
