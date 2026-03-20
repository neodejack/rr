defmodule RR.Config.ProfilesTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
  alias RR.Config.Auth
  alias RR.Config.Profiles
  alias RR.Config.Schema

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

    {:ok, store: store}
  end

  describe "state/0" do
    test "returns the current empty state without rewriting missing config", %{store: store} do
      expect(ConfigMock, :read, fn ->
        Agent.get(store, & &1)
      end)

      expect(ConfigMock, :write, 0, fn _config -> :ok end)

      assert Profiles.state() == current_state(%{})
      assert Agent.get(store, & &1) == %{}
    end

    test "keeps normalized profile config stable" do
      config =
        current_state(%{
          "prod" => %{
            "rancher_hostname" => "https://prod.example",
            "rancher_token" => "token-prod:abc",
            "aliases" => %{"api" => "prod-api"}
          }
        })

      expect(ConfigMock, :read, fn -> config end)
      expect(ConfigMock, :write, 0, fn _config -> :ok end)

      assert Profiles.state() == config
    end
  end

  describe "profile helpers" do
    setup %{store: store} do
      Agent.update(store, fn _ ->
        current_state(%{
          "prod" => %{
            "rancher_hostname" => "https://prod.example",
            "rancher_token" => "token-prod:abc",
            "aliases" => %{"api" => "production-api"}
          },
          "stage" => %{
            "rancher_hostname" => "https://stage.example",
            "rancher_token" => "token-stage:abc",
            "aliases" => %{"web" => "staging-web"}
          }
        })
      end)

      :ok
    end

    test "lists profile names in sorted order" do
      assert Profiles.names() == ["prod", "stage"]
    end

    test "normalizes profile names consistently" do
      assert Profiles.normalize_profile_name(nil) == nil
      assert Profiles.normalize_profile_name("") == nil
      assert Profiles.normalize_profile_name("   ") == nil
      assert Profiles.normalize_profile_name(" prod ") == "prod"
    end

    test "gets one profile with aliases normalized" do
      assert {:ok,
              %{
                "rancher_hostname" => "https://prod.example",
                "rancher_token" => "token-prod:abc",
                "aliases" => %{"api" => "production-api"}
              }} = Profiles.get("prod")
    end

    test "returns clear error for missing profile" do
      assert {:error, "profile 'dev' not found"} = Profiles.get("dev")
    end

    test "stores auth under a named profile and preserves aliases", %{store: store} do
      assert :ok =
               Profiles.put("prod", %Auth{
                 rancher_hostname: "https://new-prod.example",
                 rancher_token: "token-new:abc"
               })

      assert Agent.get(store, & &1) ==
               current_state(%{
                 "prod" => %{
                   "rancher_hostname" => "https://new-prod.example",
                   "rancher_token" => "token-new:abc",
                   "aliases" => %{"api" => "production-api"}
                 },
                 "stage" => %{
                   "rancher_hostname" => "https://stage.example",
                   "rancher_token" => "token-stage:abc",
                   "aliases" => %{"web" => "staging-web"}
                 }
               })
    end

    test "writes a new profile with empty aliases", %{store: store} do
      assert :ok =
               Profiles.put("dev", %Auth{
                 rancher_hostname: "https://dev.example",
                 rancher_token: "token-dev:abc"
               })

      assert Agent.get(store, & &1)["profiles"]["dev"] == %{
               "rancher_hostname" => "https://dev.example",
               "rancher_token" => "token-dev:abc",
               "aliases" => %{}
             }
    end

    test "reads aliases for one profile" do
      assert Profiles.aliases("stage") == %{"web" => "staging-web"}
    end

    test "returns aliases grouped by profile" do
      assert Profiles.aliases_by_profile() == %{
               "prod" => %{"api" => "production-api"},
               "stage" => %{"web" => "staging-web"}
             }
    end

    test "stores aliases inside the selected profile", %{store: store} do
      assert :ok = Profiles.put_alias("prod", "metrics", "prod-metrics")

      assert Agent.get(store, & &1)["profiles"]["prod"]["aliases"] == %{
               "api" => "production-api",
               "metrics" => "prod-metrics"
             }

      assert Agent.get(store, & &1)["profiles"]["stage"]["aliases"] == %{
               "web" => "staging-web"
             }
    end

    test "allows updating aliases inside the same profile", %{store: store} do
      assert :ok = Profiles.put_alias("prod", "api", "production-api-v2")

      assert Agent.get(store, & &1)["profiles"]["prod"]["aliases"] == %{
               "api" => "production-api-v2"
             }
    end

    test "rejects aliases claimed by another profile", %{store: store} do
      assert {:error, :alias_owned_by_other_profile, %{profile_name: "stage", cluster_name: "staging-web"}} =
               Profiles.put_alias("prod", "web", "prod-web")

      assert Agent.get(store, & &1)["profiles"]["prod"]["aliases"] == %{
               "api" => "production-api"
             }

      assert Agent.get(store, & &1)["profiles"]["stage"]["aliases"] == %{
               "web" => "staging-web"
             }
    end

    test "fails to store aliases for a missing profile" do
      assert {:error, "profile 'dev' not found"} = Profiles.put_alias("dev", "api", "dev-api")
    end

    test "resolves an alias to one profile" do
      assert {:ok, %{profile_name: "stage", cluster_name: "staging-web"}} =
               Profiles.resolve_alias("web")
    end

    test "raises when malformed config contains duplicate aliases", %{store: store} do
      Agent.update(store, fn _ ->
        current_state(%{
          "prod" => %{
            "rancher_hostname" => "https://prod.example",
            "rancher_token" => "token-prod:abc",
            "aliases" => %{"api" => "production-api"}
          },
          "stage" => %{
            "rancher_hostname" => "https://stage.example",
            "rancher_token" => "token-stage:abc",
            "aliases" => %{"api" => "staging-api"}
          }
        })
      end)

      assert_raise ArgumentError, ~r/alias 'api' exists more than once in local config/, fn ->
        Profiles.resolve_alias("api")
      end
    end

    test "returns :miss when alias is absent" do
      assert :miss = Profiles.resolve_alias("missing")
    end
  end

  defp current_state(profiles) do
    %{
      "schema_version" => Schema.current_version(),
      "profiles" => profiles
    }
  end
end
