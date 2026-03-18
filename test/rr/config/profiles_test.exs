defmodule RR.Config.ProfilesTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
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

    {:ok, store: store}
  end

  describe "state/0" do
    test "normalizes empty config into the explicit profiles shape", %{store: store} do
      expect(ConfigMock, :read, fn ->
        Agent.get(store, & &1)
      end)

      assert Profiles.state() == %{"profiles" => %{}}
      assert Agent.get(store, & &1) == %{"profiles" => %{}}
    end

    test "migrates legacy auth and aliases into the default profile", %{store: store} do
      Agent.update(store, fn _ ->
        %{
          "rancher_hostname" => "https://legacy.example",
          "rancher_token" => "token-legacy:abc",
          "alias" => %{"prod" => "production"}
        }
      end)

      expected_state = %{
        "profiles" => %{
          "default" => %{
            "rancher_hostname" => "https://legacy.example",
            "rancher_token" => "token-legacy:abc",
            "aliases" => %{"prod" => "production"}
          }
        }
      }

      assert Profiles.state() == expected_state
      assert Agent.get(store, & &1) == expected_state
    end

    test "keeps normalized profile config stable" do
      config = %{
        "profiles" => %{
          "prod" => %{
            "rancher_hostname" => "https://prod.example",
            "rancher_token" => "token-prod:abc",
            "aliases" => %{"api" => "prod-api"}
          }
        }
      }

      expect(ConfigMock, :read, fn -> config end)
      expect(ConfigMock, :write, 0, fn _config -> :ok end)

      assert Profiles.state() == config
    end
  end

  describe "profile helpers" do
    setup %{store: store} do
      Agent.update(store, fn _ ->
        %{
          "profiles" => %{
            "prod" => %{
              "rancher_hostname" => "https://prod.example",
              "rancher_token" => "token-prod:abc",
              "aliases" => %{"api" => "production-api"}
            },
            "stage" => %{
              "rancher_hostname" => "https://stage.example",
              "rancher_token" => "token-stage:abc",
              "aliases" => %{"api" => "staging-api", "web" => "staging-web"}
            }
          }
        }
      end)

      :ok
    end

    test "lists profile names in sorted order" do
      assert Profiles.names() == ["prod", "stage"]
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

      assert Agent.get(store, & &1) == %{
               "profiles" => %{
                 "prod" => %{
                   "rancher_hostname" => "https://new-prod.example",
                   "rancher_token" => "token-new:abc",
                   "aliases" => %{"api" => "production-api"}
                 },
                 "stage" => %{
                   "rancher_hostname" => "https://stage.example",
                   "rancher_token" => "token-stage:abc",
                   "aliases" => %{"api" => "staging-api", "web" => "staging-web"}
                 }
               }
             }
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
      assert Profiles.aliases("stage") == %{"api" => "staging-api", "web" => "staging-web"}
    end

    test "returns aliases grouped by profile" do
      assert Profiles.aliases_by_profile() == %{
               "prod" => %{"api" => "production-api"},
               "stage" => %{"api" => "staging-api", "web" => "staging-web"}
             }
    end

    test "stores aliases inside the selected profile", %{store: store} do
      assert :ok = Profiles.put_alias("prod", "web", "prod-web")

      assert Agent.get(store, & &1)["profiles"]["prod"]["aliases"] == %{
               "api" => "production-api",
               "web" => "prod-web"
             }

      assert Agent.get(store, & &1)["profiles"]["stage"]["aliases"] == %{
               "api" => "staging-api",
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

    test "reports ambiguous aliases across profiles" do
      assert {:error, :ambiguous,
              [
                %{profile_name: "prod", cluster_name: "production-api"},
                %{profile_name: "stage", cluster_name: "staging-api"}
              ]} = Profiles.resolve_alias("api")
    end

    test "returns :miss when alias is absent" do
      assert :miss = Profiles.resolve_alias("missing")
    end
  end
end
