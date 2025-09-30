defmodule RRTest do
  use ExUnit.Case
  doctest RR

  test "test we can use rancher v3 api" do
    res =
      RR.base_req()
      |> Req.get!(
        url: "/v3/clusters",
        params: [
          limit: -1,
          removed_null: 1,
          state_ne: "inactive",
          state_ne: "stopped",
          state_ne: "removing",
          system: false
        ]
      )
  end

  test "test rancher_logged_in?" do
    assert true = RR.rancher_logged_in?()
  end
end
