defmodule RR.Services.Clusters do
  @moduledoc false
  alias RR.Providers.Rancher
  alias RR.Services.Auth

  defmodule Cluster do
    @moduledoc false
    @enforce_keys [:id, :name]
    defstruct [:id, :name, :kubeconfig]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            kubeconfig: String.t() | nil
          }
  end

  def list do
    with {:ok, auth} <- Auth.ensure_valid_auth(),
         {:ok, raw_clusters} <- Rancher.get_clusters(auth) do
      {:ok, Enum.map(raw_clusters, &to_cluster/1)}
    end
  end

  def find_one(clusters, cluster_name_substring) do
    case Enum.filter(clusters, &String.contains?(&1.name, cluster_name_substring)) do
      [] ->
        {:error, "no match were found for the cluster name '#{cluster_name_substring}'"}

      [cluster] ->
        {:ok, cluster}

      [_ | _] = matched_clusters ->
        {:error,
         [
           "more than one matches were found for the cluster name '#{cluster_name_substring}'\nthese matches are found:\n",
           Enum.map(matched_clusters, &[" ", &1.name, "\n"]),
           "please make your cluster name more precise so that there will only be one single match"
         ]}
    end
  end

  defp to_cluster(raw_cluster) do
    %Cluster{id: raw_cluster["id"], name: raw_cluster["name"]}
  end
end
