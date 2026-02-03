defmodule External.RancherHttpClient do
  @moduledoc false
  alias __MODULE__
  alias RR.KubeConfig

  @callback auth_validation(%RR.Config.Auth{}) :: :ok | :error

  def auth_validation(auth), do: impl().auth_validation(auth)

  @callback get_clusters() :: {:ok, [dynamic()]} | {:error, String.t()}

  def get_clusters, do: impl().get_clusters()

  @callback get_kubeconfig!(%KubeConfig{}) :: %KubeConfig{}

  def get_kubeconfig!(kubeconfig), do: impl().get_kubeconfig!(kubeconfig)

  defp impl, do: Module.concat([RancherHttpClient, Application.get_env(:rr, :external_bound, Impl)])
end
