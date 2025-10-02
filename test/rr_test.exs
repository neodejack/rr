defmodule RRTest do
  use ExUnit.Case
  import RR.KubeConfig

  test "rancher_logged_in?" do
    assert true = rancher_logged_in?()
  end

  test "get_clusters!" do
    get_clusters!()
  end
end
