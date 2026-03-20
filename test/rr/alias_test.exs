defmodule RR.AliasTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
  alias External.RancherHttpClient.Mock, as: RancherMock
  alias RR.Alias
  alias RR.Config.Auth
  alias RR.Config.Profiles

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
    test "stores an alias inside the explicit profile through prompts" do
      put_profile("prod")

      expect(RancherMock, :get_token_info, fn %Auth{profile_name: "prod"} ->
        valid_token_info("prod")
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "prod"} ->
        {:ok, [%{"name" => "prod-admin"}, %{"name" => "production-api"}]}
      end)

      output =
        ExUnit.CaptureIO.capture_io([input: "prod-api\n2\n"], fn ->
          assert :ok = Alias.run(["-p", "prod"])
        end)

      assert output =~ "alias text"
      assert output =~ "select cluster"
      assert output =~ "profile 'prod': alias prod-api -> production-api"
      assert Profiles.aliases("prod") == %{"prod-api" => "production-api"}
    end

    test "prompts for a profile when -p is omitted" do
      put_profile("prod")
      put_profile("stage")

      expect(RancherMock, :get_token_info, fn %Auth{profile_name: "stage"} ->
        valid_token_info("stage")
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "stage"} ->
        {:ok, [%{"name" => "staging-api"}]}
      end)

      output =
        ExUnit.CaptureIO.capture_io([input: "2\nstage-api\n"], fn ->
          assert :ok = Alias.run([])
        end)

      assert output =~ "select profile"
      assert output =~ "alias text"
      assert Profiles.aliases("stage") == %{"stage-api" => "staging-api"}
      assert Profiles.aliases("prod") == %{}
    end

    test "lists aliases grouped by profile" do
      put_profile("prod")
      put_profile("stage")

      Profiles.put_alias("prod", "api", "production-api")
      Profiles.put_alias("stage", "web", "staging-web")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = Alias.run(["--list"])
        end)

      assert output =~ "these aliases are found"
      assert output =~ "prod"
      assert output =~ "api -> production-api"
      assert output =~ "stage"
      assert output =~ "web -> staging-web"
    end

    test "fails early when the requested profile is missing" do
      expect(RancherMock, :get_token_info, 0, fn _auth -> valid_token_info("unused") end)
      expect(RancherMock, :get_clusters, 0, fn _auth -> {:ok, []} end)

      assert {:error, "profile 'missing' not found"} =
               Alias.run(["-p", "missing"])
    end

    test "rejects an alias already claimed by another profile before network calls" do
      put_profile("prod")
      put_profile("stage")
      Profiles.put_alias("stage", "shared", "staging-api")

      expect(RancherMock, :get_token_info, 0, fn _auth -> valid_token_info("unused") end)
      expect(RancherMock, :get_clusters, 0, fn _auth -> {:ok, []} end)

      output =
        ExUnit.CaptureIO.capture_io([input: "shared\n"], fn ->
          send(self(), {:result, Alias.run(["-p", "prod"])})
        end)

      assert_received {:result,
                       {:error, "alias 'shared' is already claimed by profile 'stage' for cluster 'staging-api'"}}

      assert output =~ "alias text"
      assert Profiles.aliases("prod") == %{}
    end

    test "confirms before overwriting an alias in the same profile" do
      put_profile("prod")
      Profiles.put_alias("prod", "api", "production-api")

      expect(RancherMock, :get_token_info, fn %Auth{profile_name: "prod"} ->
        valid_token_info("prod")
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "prod"} ->
        {:ok, [%{"name" => "prod-admin"}, %{"name" => "production-api-v2"}]}
      end)

      output =
        ExUnit.CaptureIO.capture_io([input: "api\n2\ny\n"], fn ->
          assert :ok = Alias.run(["-p", "prod"])
        end)

      assert output =~ "already points to 'production-api'"
      assert Profiles.aliases("prod") == %{"api" => "production-api-v2"}
    end

    test "leaves the alias unchanged when overwrite confirmation is declined" do
      put_profile("prod")
      Profiles.put_alias("prod", "api", "production-api")

      expect(RancherMock, :get_token_info, fn %Auth{profile_name: "prod"} ->
        valid_token_info("prod")
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "prod"} ->
        {:ok, [%{"name" => "prod-admin"}, %{"name" => "production-api-v2"}]}
      end)

      output =
        ExUnit.CaptureIO.capture_io([input: "api\n2\nn\n"], fn ->
          assert :ok = Alias.run(["-p", "prod"])
        end)

      assert output =~ "already points to 'production-api'"
      assert Profiles.aliases("prod") == %{"api" => "production-api"}
    end

    test "fails clearly when the selected profile has no clusters" do
      put_profile("prod")

      expect(RancherMock, :get_token_info, fn %Auth{profile_name: "prod"} ->
        valid_token_info("prod")
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "prod"} ->
        {:ok, []}
      end)

      output =
        ExUnit.CaptureIO.capture_io([input: "api\n"], fn ->
          send(self(), {:result, Alias.run(["-p", "prod"])})
        end)

      assert_received {:result, {:error, "no clusters found for profile 'prod'"}}
      assert output =~ "alias text"
      assert Profiles.aliases("prod") == %{}
    end
  end

  defp put_profile(profile_name) do
    Profiles.put(
      profile_name,
      %Auth{
        profile_name: profile_name,
        rancher_hostname: "https://#{profile_name}.example",
        rancher_token: "token-#{profile_name}:abc"
      }
    )
  end

  defp clear_auth_cache do
    case :ets.whereis(:rr_auth_cache) do
      :undefined -> :ok
      _tid -> :ets.delete(:rr_auth_cache)
    end
  end

  defp valid_token_info(description) do
    now_ms = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok,
     %{
       description: description,
       expired: false,
       enabled: true,
       created_ts: now_ms - 300_000,
       ttl: 864_000_000
     }}
  end
end
