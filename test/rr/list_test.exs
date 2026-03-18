defmodule RR.ListTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
  alias External.RancherHttpClient.Mock, as: RancherMock
  alias RR.Config
  alias RR.Config.Auth
  alias RR.List

  setup :verify_on_exit!

  setup do
    store = start_supervised!({Agent, fn -> %{} end})

    stub(ConfigMock, :read, fn ->
      Agent.get(store, & &1)
    end)

    stub(ConfigMock, :write, fn config ->
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

  describe "run/1" do
    test "renders a table of cluster names and ids" do
      clusters = [
        %{"id" => "c-1", "name" => "dev"},
        %{"id" => "c-9999", "name" => "production"}
      ]

      expect(RancherMock, :get_token_info, fn %Auth{} ->
        valid_token_info()
      end)

      expect(RancherMock, :get_clusters, fn %Auth{
                                              profile_name: "default",
                                              rancher_hostname: "https://rancher.example",
                                              rancher_token: "token-123:abc"
                                            } ->
        {:ok, clusters}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run([]) end)

      assert output =~ "NAME"
      assert output =~ "ID"
      assert output =~ "dev"
      assert output =~ "production"
      assert output =~ "c-1"
      assert output =~ "c-9999"
    end

    test "renders empty state when no clusters returned" do
      expect(RancherMock, :get_token_info, fn %Auth{} ->
        valid_token_info()
      end)

      expect(RancherMock, :get_clusters, fn %Auth{} ->
        {:ok, []}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run([]) end)

      assert output =~ "NAME"
      assert output =~ "no clusters found"
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
