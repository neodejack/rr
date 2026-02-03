defmodule External.RancherHttpClient do
  @moduledoc false
  alias __MODULE__
  alias RR.Config.Auth
  alias RR.KubeConfig

  @callback get_clusters() :: {:ok, [dynamic()]} | {:error, String.t()}

  def get_clusters, do: impl().get_clusters()

  @callback get_kubeconfig!(%KubeConfig{}) :: %KubeConfig{}

  def get_kubeconfig!(kubeconfig), do: impl().get_kubeconfig!(kubeconfig)

  @callback get_token_info(%Auth{}) :: any()

  def get_token_info(auth), do: impl().get_token_info(auth)

  defp impl, do: Module.concat([RancherHttpClient, Application.get_env(:rr, :external_bound, Impl)])
end
