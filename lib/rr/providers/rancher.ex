defmodule RR.Providers.Rancher do
  @moduledoc false

  alias __MODULE__

  @callback get_clusters(auth :: struct()) :: {:ok, [map()]} | {:error, String.t()}
  def get_clusters(auth), do: impl().get_clusters(auth)

  @callback get_kubeconfig(auth :: struct(), cluster :: struct()) ::
              {:ok, struct()} | {:error, String.t()}
  def get_kubeconfig(auth, cluster), do: impl().get_kubeconfig(auth, cluster)

  @type token_info :: %{
          description: binary(),
          expired: boolean(),
          enabled: boolean(),
          created_ts: integer(),
          ttl: integer()
        }
  @type token_error_reason :: :unauthorized | :unknown
  @type token_error :: {:error, token_error_reason(), binary()}

  @callback get_token_info(auth :: struct()) :: {:ok, token_info()} | token_error()
  def get_token_info(auth), do: impl().get_token_info(auth)

  defp impl, do: Module.concat([Rancher, Application.get_env(:rr, :external_bound, Impl)])
end
