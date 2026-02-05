defmodule RR.Config.AuthTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock
  alias RR.Config
  alias RR.Config.Auth

  setup :verify_on_exit!

  setup do
    store = start_supervised!({Agent, fn -> %{} end})

    stub(Mock, :read, fn ->
      Agent.get(store, & &1)
    end)

    stub(Mock, :write, fn config ->
      Agent.update(store, fn _ -> config end)
      :ok
    end)

    clear_auth_cache()
    Config.put_auth({"https://rancher.example", "token-123:abc"})

    on_exit(fn ->
      clear_auth_cache()
    end)

    :ok
  end

  describe "ensure_valid_auth/0" do
    test "internet connection error" do
      expect(External.RancherHttpClient.Mock, :get_token_info, fn _ ->
        {:error, inspect(%Req.TransportError{reason: :nxdomain})}
      end)

      assert {:error, reason} = Auth.ensure_valid_auth()
      assert reason =~ "nxdomain"
    end

    test "uses cached auth to avoid re-validating the token" do
      expect(External.RancherHttpClient.Mock, :get_token_info, 1, fn _ ->
        valid_token_info()
      end)

      assert {:ok, _} = Auth.ensure_valid_auth()
      assert {:ok, _} = Auth.ensure_valid_auth()
    end
  end

  defp clear_auth_cache do
    case :ets.whereis(:rr_auth_cache) do
      :undefined -> :ok
      _tid -> :ets.delete(:rr_auth_cache)
    end
  end

  defp valid_token_info do
    now_ms = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok,
     %{
       description: "foo",
       expired: false,
       enabled: true,
       created_ts: now_ms - 300_000,
       ttl: 864_000_000
     }}
  end
end
