defmodule RR.Config do
  @moduledoc false

  alias RR.Config.Auth
  alias RR.Config.Profiles
  alias RR.Config.Schema

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
    External.Config.read()
    |> ensure_current_shape()
  end

  defp write(config) do
    config
    |> ensure_current_shape()
    |> External.Config.write()
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
    case Profiles.get("default") do
      {:ok, profile} ->
        {profile["rancher_hostname"], profile["rancher_token"]}

      {:error, _reason} ->
        {nil, nil}
    end
  end

  def put_auth({rancher_hostname, rancher_token}) do
    Profiles.put("default", %Auth{
      profile_name: "default",
      rancher_hostname: rancher_hostname,
      rancher_token: rancher_token
    })
  end

  defp ensure_current_shape(config) when is_map(config) do
    config
    |> Map.put_new("schema_version", Schema.current_version())
    |> Map.put_new("profiles", %{})
  end

  defp ensure_current_shape(_config), do: Schema.empty_state()
end
