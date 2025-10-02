defmodule RRTest do
  use ExUnit.Case
  import RR.Kf

  test "rancher_logged_in?" do
    assert true = rancher_logged_in?()
  end

  test "get_clusters!" do
    get_clusters!()
  end

  test "get_cluster_id_by_name" do
    clusters = [
      %{id: "1", name: "name1"},
      %{id: "2", name: "name2"},
      %{id: "3", name: "name3"},
      %{id: "4", name: "name4"},
      %{id: "5", name: "name5"}
    ]

    assert "1" == get_cluster_id_by_name("name1", clusters)
  end

  test "get_kubeconfig!" do
    get_kubeconfig!("c-m-5qxl56v9")
  end
end
