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
end
