defmodule RR.Config.AuthTest do
  use ExUnit.Case, async: true

  import Mox

  alias RR.Config.Auth

  setup :verify_on_exit!

  describe "valid_auth?/1" do
    test "internet connection error" do
      expect(External.RancherHttpClient.Mock, :auth_validation, fn _ ->
        {:error, %Req.TransportError{reason: :nxdomain}}
      end)

      assert false == Auth.valid_auth?(valid_auth_data())
    end
  end

  def valid_auth_data, do: %Auth{rancher_hostname: "valid", rancher_token: "valid"}
end
