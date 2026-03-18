defmodule RR.Config.AuthTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock
  alias RR.Config
  alias RR.Config.Auth
  alias RR.Config.Profiles

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

  describe "ensure_valid_auth/1" do
    test "internet connection error" do
      expect(External.RancherHttpClient.Mock, :get_token_info, fn _ ->
        {:error, :unknown, inspect(%Req.TransportError{reason: :nxdomain})}
      end)

      assert {:error, :unknown, reason} = Auth.ensure_valid_auth("default")
      assert reason =~ "nxdomain"
    end

    test "uses cached auth to avoid re-validating the token" do
      expect(External.RancherHttpClient.Mock, :get_token_info, 1, fn _ ->
        valid_token_info()
      end)

      assert {:ok, _} = Auth.ensure_valid_auth("default")
      assert {:ok, _} = Auth.ensure_valid_auth("default")
    end

    test "keeps cache entries separate per profile even with the same token" do
      Profiles.put(
        "stage",
        %Auth{
          profile_name: "stage",
          rancher_hostname: "https://rancher.example",
          rancher_token: "token-123:abc"
        }
      )

      expect(External.RancherHttpClient.Mock, :get_token_info, 2, fn _ ->
        valid_token_info()
      end)

      assert {:ok, %Auth{profile_name: "default"}} = Auth.ensure_valid_auth("default")
      assert {:ok, %Auth{profile_name: "stage"}} = Auth.ensure_valid_auth("stage")

      tid = :ets.whereis(:rr_auth_cache)
      assert :ets.lookup(tid, {"default", "https://rancher.example", "token-123:abc"}) != []
      assert :ets.lookup(tid, {"stage", "https://rancher.example", "token-123:abc"}) != []
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
