defmodule RR.Config.MigratorTest do
  use ExUnit.Case, async: true

  alias RR.Config.Migrator
  alias RR.Config.Schema

  describe "migrate/2" do
    test "migrates legacy root auth and aliases into the default profile" do
      current_version = Schema.current_version()

      legacy_config = %{
        "rancher_hostname" => "https://legacy.example",
        "rancher_token" => "token-legacy:abc",
        "alias" => %{"prod" => "production"}
      }

      assert {:ok,
              %{
                "schema_version" => ^current_version,
                "profiles" => %{
                  "default" => %{
                    "rancher_hostname" => "https://legacy.example",
                    "rancher_token" => "token-legacy:abc",
                    "aliases" => %{"prod" => "production"}
                  }
                }
              }} = Migrator.migrate(legacy_config, 0)
    end

    test "adds schema_version to the unversioned profiles layout" do
      current_version = Schema.current_version()

      config = %{
        "profiles" => %{
          "prod" => %{
            "rancher_hostname" => "https://prod.example",
            "rancher_token" => "token-prod:abc"
          }
        }
      }

      assert {:ok,
              %{
                "schema_version" => ^current_version,
                "profiles" => %{
                  "prod" => %{
                    "rancher_hostname" => "https://prod.example",
                    "rancher_token" => "token-prod:abc",
                    "aliases" => %{}
                  }
                }
              }} = Migrator.migrate(config, 0)
    end

    test "fails when legacy root auth fields are malformed" do
      config = %{
        "rancher_hostname" => nil,
        "rancher_token" => "token-legacy:abc"
      }

      assert {:error, "legacy config is malformed: expected rancher_hostname and rancher_token to be strings"} =
               Migrator.migrate(config, 0)
    end

    test "fails when an unversioned profile has invalid aliases" do
      config = %{
        "profiles" => %{
          "prod" => %{
            "rancher_hostname" => "https://prod.example",
            "rancher_token" => "token-prod:abc",
            "aliases" => %{"api" => 123}
          }
        }
      }

      assert {:error, "legacy config is malformed: profile 'prod' has invalid aliases"} =
               Migrator.migrate(config, 0)
    end
  end
end
