defmodule RRTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
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
             calls: %{read: 0, read_result: 0, backup: 0, write: 0}
           }
         end}
      )

    stub(ConfigMock, :read, fn ->
      Agent.get_and_update(store, fn state ->
        {state.config, put_in(state, [:calls, :read], state.calls.read + 1)}
      end)
    end)

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

  describe "run/1" do
    test "stateful commands bootstrap legacy config before dispatch", %{store: store} do
      legacy_config = %{
        "rancher_hostname" => "https://legacy.example",
        "rancher_token" => "token-legacy:abc",
        "alias" => %{"prod" => "production"}
      }

      Agent.update(store, fn state -> %{state | config: legacy_config} end)

      stdout =
        ExUnit.CaptureIO.capture_io(fn ->
          stderr =
            ExUnit.CaptureIO.capture_io(:stderr, fn ->
              assert :ok = RR.run(["alias", "--list"])
            end)

          send(self(), {:stderr, stderr})
        end)

      assert stdout =~ "these aliases are found"
      assert_received {:stderr, stderr}

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

      assert Agent.get(store, & &1.calls) == %{read: 1, read_result: 1, backup: 1, write: 1}
    end

    test "subcommand help skips bootstrap and config I/O", %{store: store} do
      stdout = ExUnit.CaptureIO.capture_io(fn -> assert :ok = RR.run(["alias", "--help"]) end)

      assert stdout =~ "`rr alias` set alias."
      assert Agent.get(store, & &1.calls) == %{read: 0, read_result: 0, backup: 0, write: 0}
      assert Agent.get(store, & &1.backup) == nil
    end

    test "version skips bootstrap and config I/O", %{store: store} do
      stdout = ExUnit.CaptureIO.capture_io(fn -> assert :ok = RR.run(["--version"]) end)

      assert stdout =~ to_string(Application.spec(:rr)[:vsn])
      assert Agent.get(store, & &1.calls) == %{read: 0, read_result: 0, backup: 0, write: 0}
      assert Agent.get(store, & &1.backup) == nil
    end
  end

  defp current_state(profiles) do
    %{
      "schema_version" => Schema.current_version(),
      "profiles" => profiles
    }
  end
end
