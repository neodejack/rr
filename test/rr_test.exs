defmodule RRTest do
  use ExUnit.Case
  import RR.KubeConfig

  test "rancher_logged_in?" do
    assert true = rancher_logged_in?()
  end

  test "get_clusters!" do
    clusters = get_clusters!()
    IO.inspect(clusters)
  end

  test "select_cluster" do
    select_cluster([
      %RR.KubeConfig{
        id: "xxxxxx-id1",
        name: "cluster-1-name",
        kubeconfig: nil
      },
      %RR.KubeConfig{
        id: "xxxxxx-id2",
        name: "cluster-2-name",
        kubeconfig: nil
      }
    ])
  end
end
