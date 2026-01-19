defmodule RR.Config do
  @moduledoc false
  @config "config.json"

  def delete(key) do
    read()
    |> Map.delete(key)
    |> write()
  end

  def put(key, value) do
    read()
    |> Map.put(key, value)
    |> write()
  end

  def put_in(key, value) do
    read()
    |> Kernel.put_in(key, value)
    |> write()
  end

  def get_in(key) do
    Kernel.get_in(read(), key)
  end

  def get(key) do
    Map.get(read(), key)
  end

  defp read do
    with {:ok, binary} <- File.read(file()),
         {:ok, term} <-
           JSON.decode(binary) do
      term
    else
      _ ->
        %{}
    end
  end

  defp write(config) do
    if not File.dir?(home_dir()) do
      File.mkdir_p!(home_dir())
    end

    File.write!(file(), JSON.encode!(config))
  end

  defp file do
    home_dir() |> Path.join(@config) |> Path.expand()
  end

  def home_dir do
    override_dir = System.get_env("RR_HOME")

    if override_dir == nil or override_dir == "" do
      Path.expand("~/.rr")
    else
      Path.expand(override_dir)
    end
  end

  def get_auth do
    {get("rancher_hostname"), get("rancher_token")}
  end

  def put_auth({rancher_hostname, rancher_token}) do
    put("rancher_hostname", rancher_hostname)
    put("rancher_token", rancher_token)
  end
end
