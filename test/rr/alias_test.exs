defmodule RR.AliasTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
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

    :ok
  end

  describe "run/1" do
    test "stores an alias inside the explicit profile" do
      Profiles.put(
        "prod",
        %Auth{
          profile_name: "prod",
          rancher_hostname: "https://prod.example",
          rancher_token: "token-prod:abc"
        }
      )

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = Alias.run(["-p", "prod", "api", "production-api"])
        end)

      assert output =~ "profile 'prod': alias api -> production-api"
      assert Profiles.aliases("prod") == %{"api" => "production-api"}
    end

    test "prompts for a profile when -p is omitted" do
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

      output =
        ExUnit.CaptureIO.capture_io([input: "2\n"], fn ->
          assert :ok = Alias.run(["api", "staging-api"])
        end)

      assert output =~ "select profile"
      assert Profiles.aliases("stage") == %{"api" => "staging-api"}
      assert Profiles.aliases("prod") == %{}
    end

    test "lists aliases grouped by profile" do
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
      assert {:error, "profile 'missing' not found"} =
               Alias.run(["-p", "missing", "api", "missing-api"])
    end
  end
end
