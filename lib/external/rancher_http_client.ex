defmodule External.RancherHttpClient do
  @moduledoc false
  use External

  alias RR.Config.Auth
  alias RR.KubeConfig

  @type token_info :: %{
          description: binary(),
          expired: boolean(),
          enabled: boolean(),
          created_ts: integer(),
          ttl: integer()
        }
  @type token_error_reason :: :unauthorized | :unknown
  @type token_error :: {:error, token_error_reason(), binary()}

  defcallback(get_clusters() :: {:ok, [dynamic()]} | {:error, String.t()})
  defcallback(get_kubeconfig!(%KubeConfig{}) :: %KubeConfig{})
  defcallback(get_token_info(%Auth{}) :: {:ok, token_info()} | token_error())
end
