defmodule RRTest.RR.Login do
  use ExUnit.Case
  import RR.Login

  test "write_to_config_file" do
    write_to_config_file(%RR.Login{
      state: :no_auth_config,
      rancher_hostname: "https://test.com",
      rancher_token: "token:test"
    })
  end
end
