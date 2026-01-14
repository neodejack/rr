defmodule RRTest.RR.Config.Auth do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  describe "is_valid_auth?/1" do
    test "internet connection error" do
      expect(External.RancherHttpClient.Mock, :auth_validation, fn _ ->
        {:error, %Req.TransportError{reason: :nxdomain}}
      end)

      assert false == valid_auth_data() |> RR.Config.Auth.is_valid_auth?()
    end
  end

  def valid_auth_data(), do: %RR.Config.Auth{rancher_hostname: "valid", rancher_token: "valid"}
end
