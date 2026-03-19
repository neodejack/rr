defmodule RR.KubeConfigTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
  alias External.RancherHttpClient.Mock, as: RancherMock
  alias RR.Config.Auth
  alias RR.Config.Profiles
  alias RR.KubeConfig

  setup :verify_on_exit!

  setup do
    store = start_supervised!({Agent, fn -> %{} end})
    rr_home = Path.join(System.tmp_dir!(), "rr-kf-test-#{System.unique_integer([:positive])}")
    previous_rr_home = System.get_env("RR_HOME")

    stub(ConfigMock, :read, fn ->
      Agent.get(store, & &1)
    end)

    stub(ConfigMock, :write, fn config ->
      Agent.update(store, fn _ -> config end)
      :ok
    end)

    System.put_env("RR_HOME", rr_home)
    clear_auth_cache()

    on_exit(fn ->
      clear_auth_cache()

      if previous_rr_home do
        System.put_env("RR_HOME", previous_rr_home)
      else
        System.delete_env("RR_HOME")
      end

      File.rm_rf(rr_home)
    end)

    {:ok, rr_home: rr_home}
  end

  describe "run/1" do
    test "fails early when the requested profile is missing" do
      expect(RancherMock, :get_token_info, 0, fn _auth -> valid_token_info("unused") end)
      expect(RancherMock, :get_clusters, 0, fn _auth -> {:ok, []} end)
      expect(RancherMock, :get_kubeconfig, 0, fn _auth, kubeconfig -> {:ok, kubeconfig} end)

      assert {:error, "profile 'missing' not found"} = KubeConfig.run(["-p", "missing", "api"])
    end

    test "resolves a profile-scoped alias and writes a profile-scoped kubeconfig", %{rr_home: rr_home} do
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

      Profiles.put_alias("prod", "prod-api", "production-api")

      expect(RancherMock, :get_token_info, fn %Auth{profile_name: "prod"} ->
        valid_token_info("prod")
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "prod"} ->
        {:ok, [%{"id" => "c-prod", "name" => "production-api"}]}
      end)

      expect(
        RancherMock,
        :get_kubeconfig,
        fn %Auth{profile_name: "prod"},
           %KubeConfig{profile_name: "prod", id: "c-prod", name: "production-api"} = kubeconfig ->
          {:ok, %{kubeconfig | kubeconfig: "apiVersion: v1\nclusters: []\n"}}
        end
      )

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          ExUnit.CaptureIO.capture_io(:stderr, fn ->
            assert :ok = KubeConfig.run(["--new", "prod-api"])
          end)
        end)

      expected_path = Path.join([rr_home, "kubeconfigs", "prod", "production-api"])

      assert output =~ expected_path
      assert File.read!(expected_path) =~ "apiVersion: v1"
    end

    test "reports ambiguous matches across profiles with guidance" do
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

      expect(RancherMock, :get_token_info, 2, fn %Auth{profile_name: profile_name} ->
        valid_token_info(profile_name)
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "prod"} ->
        {:ok, [%{"id" => "c-prod", "name" => "api"}]}
      end)

      expect(RancherMock, :get_clusters, fn %Auth{profile_name: "stage"} ->
        {:ok, [%{"id" => "c-stage", "name" => "api"}]}
      end)

      assert {:error, message} = KubeConfig.run(["api"])
      assert message =~ "prod -> api"
      assert message =~ "stage -> api"
      assert message =~ "please use -p auth_name to specify the cluster"
    end
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
