defmodule RR.Config.BootstrapTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
  alias RR.Config.Bootstrap
  alias RR.Config.Schema

  setup :verify_on_exit!

  setup do
    store =
      start_supervised!(
        {Agent,
         fn ->
           %{
             config: %{},
             backup: nil,
             calls: %{read_result: 0, backup: 0, write: 0}
           }
         end}
      )

    stub(ConfigMock, :read_result, fn ->
      Agent.get_and_update(store, fn state ->
        {{:ok, state.config}, put_in(state, [:calls, :read_result], state.calls.read_result + 1)}
      end)
    end)

    stub(ConfigMock, :backup, fn ->
      Agent.get_and_update(store, fn state ->
        next_state =
          state
          |> Map.put(:backup, state.config)
          |> put_in([:calls, :backup], state.calls.backup + 1)

        {{:ok, "/tmp/config.json.bak"}, next_state}
      end)
    end)

    stub(ConfigMock, :write, fn config ->
      Agent.update(store, fn state ->
        state
        |> Map.put(:config, config)
        |> put_in([:calls, :write], state.calls.write + 1)
      end)

      :ok
    end)

    {:ok, store: store}
  end

  describe "ensure_current/0" do
    test "leaves current schema config untouched", %{store: store} do
      Agent.update(store, fn _ ->
        %{
          config: current_state(%{
            "prod" => %{
              "rancher_hostname" => "https://prod.example",
              "rancher_token" => "token-prod:abc",
              "aliases" => %{"api" => "prod-api"}
            }
          }),
          backup: nil,
          calls: %{read_result: 0, backup: 0, write: 0}
        }
      end)

      stderr = ExUnit.CaptureIO.capture_io(:stderr, fn -> assert :ok = Bootstrap.ensure_current() end)

      assert stderr == ""
      assert Agent.get(store, & &1.backup) == nil
      assert Agent.get(store, & &1.calls) == %{read_result: 1, backup: 0, write: 0}
    end

    test "migrates legacy config, creates a backup, and emits notices", %{store: store} do
      legacy_config = %{
        "rancher_hostname" => "https://legacy.example",
        "rancher_token" => "token-legacy:abc",
        "alias" => %{"prod" => "production"}
      }

      Agent.update(store, fn state -> %{state | config: legacy_config} end)

      stderr = ExUnit.CaptureIO.capture_io(:stderr, fn -> assert :ok = Bootstrap.ensure_current() end)

      assert stderr =~ "config schema 0 detected, migrating to 1"
      assert stderr =~ "config migration complete"

      assert Agent.get(store, & &1.backup) == legacy_config

      assert Agent.get(store, & &1.config) ==
               current_state(%{
                 "default" => %{
                   "rancher_hostname" => "https://legacy.example",
                   "rancher_token" => "token-legacy:abc",
                   "aliases" => %{"prod" => "production"}
                 }
               })

      assert Agent.get(store, & &1.calls) == %{read_result: 1, backup: 1, write: 1}
    end

    test "fails fast for malformed legacy config without backup or rewrite", %{store: store} do
      Agent.update(store, fn state ->
        %{state | config: %{"rancher_hostname" => "https://legacy.example"}}
      end)

      stderr =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          assert {:error,
                  "config migration failed: legacy config is malformed: expected rancher_hostname and rancher_token to be strings"} =
                   Bootstrap.ensure_current()
        end)

      assert stderr == ""
      assert Agent.get(store, & &1.backup) == nil
      assert Agent.get(store, & &1.config) == %{"rancher_hostname" => "https://legacy.example"}
      assert Agent.get(store, & &1.calls) == %{read_result: 1, backup: 0, write: 0}
    end
  end

  defp current_state(profiles) do
    %{
      "schema_version" => Schema.current_version(),
      "profiles" => profiles
    }
  end
end
