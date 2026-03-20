defmodule RR.ListTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
  alias External.RancherHttpClient.Mock, as: RancherMock
  alias RR.Config.Auth
  alias RR.Config.Profiles
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

    on_exit(fn ->
      clear_auth_cache()
    end)

    :ok
  end

  describe "run/1" do
    test "renders a profile-aware table for one explicit profile" do
      Profiles.put(
        "prod",
        %Auth{
          profile_name: "prod",
          rancher_hostname: "https://prod.example",
          rancher_token: "token-prod:abc"
        }
      )

      expect(RancherMock, :get_token_info, fn %Auth{profile_name: "prod"} ->
        valid_token_info()
      end)

      expect(RancherMock, :get_clusters, fn %Auth{
                                              profile_name: "prod",
                                              rancher_hostname: "https://prod.example",
                                              rancher_token: "token-prod:abc"
                                            } ->
        {:ok, [%{"id" => "c-prod", "name" => "production"}]}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run(["-p", "prod"]) end)

      assert output =~ "PROFILE"
      assert output =~ "NAME"
      assert output =~ "ID"
      assert output =~ "prod"
      assert output =~ "production"
      assert output =~ "c-prod"
    end

    test "renders the same profile-aware table when no profile is provided" do
      Profiles.put(
        "prod",
        %Auth{
          profile_name: "prod",
          rancher_hostname: "https://prod.example",
          rancher_token: "token-prod:abc"
        }
      )

      Profiles.put(
        "stage",
        %Auth{
          profile_name: "stage",
          rancher_hostname: "https://stage.example",
          rancher_token: "token-stage:abc"
        }
      )

      expect(RancherMock, :get_token_info, 2, fn %Auth{} ->
        valid_token_info()
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "prod"} ->
        {:ok, [%{"id" => "c-prod", "name" => "production"}]}
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "stage"} ->
        {:ok, [%{"id" => "c-stage", "name" => "staging"}]}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run([]) end)

      assert output =~ "PROFILE"
      assert output =~ "NAME"
      assert output =~ "prod"
      assert output =~ "stage"
      assert output =~ "production"
      assert output =~ "staging"
    end

    test "fails early when the requested profile is missing" do
      expect(RancherMock, :get_token_info, 0, fn _auth -> valid_token_info() end)
      expect(RancherMock, :get_clusters, 0, fn _auth -> {:ok, []} end)

      assert {:error, "profile 'missing' not found"} = List.run(["-p", "missing"])
    end

    test "returns a clear error when no profiles are configured" do
      expect(RancherMock, :get_token_info, 0, fn _auth -> valid_token_info() end)
      expect(RancherMock, :get_clusters, 0, fn _auth -> {:ok, []} end)

      assert {:error, "no profiles configured\nto login, run: rr login"} = List.run([])
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
