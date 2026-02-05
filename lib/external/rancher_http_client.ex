defmodule External.RancherHttpClient do
  @moduledoc false
  alias __MODULE__
  alias RR.Config.Auth
  alias RR.KubeConfig

  @callback get_clusters() :: {:ok, [dynamic()]} | {:error, String.t()}

  def get_clusters, do: impl().get_clusters()

  @callback get_kubeconfig!(%KubeConfig{}) :: %KubeConfig{}

  def get_kubeconfig!(kubeconfig), do: impl().get_kubeconfig!(kubeconfig)

  @type token_info :: %{
          description: binary(),
          expired: boolean(),
          enabled: boolean(),
          created_ts: integer(),
          ttl: integer()
        }
  @type token_error_reason :: :unauthorized | :unknown
  @type token_error :: {:error, token_error_reason(), binary()}

  @callback get_token_info(%Auth{}) :: {:ok, token_info()} | token_error()

  def get_token_info(auth), do: impl().get_token_info(auth)

  defp impl, do: Module.concat([RancherHttpClient, Application.get_env(:rr, :external_bound, Impl)])
end
