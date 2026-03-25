defmodule RR.Services.Kubeconfigs do
  @moduledoc false
  alias RR.Config.Paths
  alias RR.Providers.Rancher
  alias RR.Services.Aliases
  alias RR.Services.Auth
  alias RR.Services.Clusters
  alias RR.Shell

  def fetch(cluster_name_substring, opts \\ []) do
    cluster_name_substring = Aliases.resolve(cluster_name_substring)

    with {:ok, _auth} <- Auth.ensure_valid_auth(),
         {:ok, clusters} <- Clusters.list(),
         {:ok, target_cluster} <- Clusters.find_one(clusters, cluster_name_substring) do
      ensure_valid_kubeconfig(target_cluster, Keyword.get(opts, :overwrite, false))
    end
  end

  def ensure_valid_kubeconfig(cluster, overwrite_existing_kf)

  def ensure_valid_kubeconfig(cluster, false) do
    if kf_valid?(cluster) do
      Shell.info_stderr("found existing valid kubeconifg: #{kubeconfig_file_path(cluster)}")

      {:ok, kubeconfig_file_path(cluster)}
    else
      with {:ok, auth} <- Auth.ensure_valid_auth() do
        auth
        |> Rancher.get_kubeconfig(cluster)
        |> save_to_file()
      end
    end
  end

  def ensure_valid_kubeconfig(cluster, true) do
    Shell.info_stderr("overwriting existing valid kubeconfig: #{kubeconfig_file_path(cluster)}")

    with {:ok, auth} <- Auth.ensure_valid_auth() do
      auth
      |> Rancher.get_kubeconfig(cluster)
      |> save_to_file()
    end
  end

  def kf_valid?(cluster) do
    path = kubeconfig_file_path(cluster)

    if File.exists?(path) do
      case System.cmd("kubectl", ["get", "pods", "--kubeconfig=#{path}"], stderr_to_stdout: true) do
        {_, 0} -> true
        {_, 1} -> false
      end
    end
  end

  def save_to_file({:ok, cluster}) do
    with :ok <- File.mkdir_p(Paths.kubeconfig_dir()),
         kb_path = kubeconfig_file_path(cluster),
         :ok <- File.write(kb_path, cluster.kubeconfig) do
      Shell.info_stderr(["new kubeconfig is saved to ", kb_path])
      {:ok, kb_path}
    else
      {:error, err} -> {:error, ["error when saving kubeconfig:\n", err]}
    end
  end

  def save_to_file({:error, _} = error), do: error

  def kubeconfig_file_path(%Clusters.Cluster{name: name}) do
    Path.join(Paths.kubeconfig_dir(), name)
  end
end
