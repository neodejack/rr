defmodule RR.Config.AuthTest do
  use ExUnit.Case, async: true

  import Mox

  alias RR.Config.Auth

  setup :verify_on_exit!

  describe "ensure_valid_auth/0" do
    test "internet connection error" do
      expect(External.RancherHttpClient.Mock, :get_token_info, fn _ ->
        {:error, inspect(%Req.TransportError{reason: :nxdomain})}
      end)

      assert {:error, reason} = Auth.ensure_valid_auth()
      assert reason =~ "nxdomain"
    end
  end

  defp expired_token_info do
    {:error, "rancher token is not valid\nrun `rr login` to input a valid token"}
  end

  defp almost_expiring_token_data do
    {:ok,
     %{
       description: "almost expiring token",
       expired: false,
       enabled: true,
       created_ts: DateTime.shift(DateTime.utc_now(), day: -3),
       ttl: 604_800_000
     }}
  end

  defp mock_valid_token_data,
    do:
      {:ok,
       %{
         description: "foo",
         expired: false,
         enabled: true,
         created_ts: DateTime.shift(DateTime.utc_now(), minute: -5),
         ttl: 864_000_000
       }}
end
