defmodule RR.CLI.Commands.LoginTest do
  use ExUnit.Case, async: false

  import Mox

  alias RR.CLI
  alias RR.CLI.Commands.Login
  alias RR.CLI.ParseError
  alias RR.Providers.AuthCache.Mock, as: AuthCacheMock
  alias RR.Providers.Rancher.Mock, as: RancherMock
  alias RR.Providers.SettingsStore.Mock, as: SettingsStoreMock
  alias RR.Providers.Terminal.Mock, as: TerminalMock
  alias RR.Services.Auth
  alias RR.Settings

  @day_ms 86_400_000
  @hostname "https://rancher.example"
  @token_invalid "token-old:abc"
  @token_expiring_in_7_days "token-expiring:abc"
  @token_valid "token-valid:abc"

  setup :verify_on_exit!

  setup do
    TerminalMock.reset()
    store = start_supervised!({Agent, fn -> %{} end}, id: make_ref())
    cache = start_supervised!({Agent, fn -> %{} end}, id: make_ref())

    stub(SettingsStoreMock, :read, fn ->
      Agent.get(store, & &1)
    end)

    stub(SettingsStoreMock, :write, fn config ->
      Agent.update(store, fn _ -> config end)
      :ok
    end)

    stub(AuthCacheMock, :get, fn key ->
      Agent.get(cache, fn entries ->
        case Map.fetch(entries, key) do
          {:ok, valid?} -> {:hit, valid?}
          :error -> :miss
        end
      end)
    end)

    stub(AuthCacheMock, :put, fn key, valid? ->
      Agent.update(cache, &Map.put(&1, key, valid?))
      :ok
    end)

    :ok
  end

  describe "build_action/2" do
    test "returns an action for empty positional args" do
      assert {:ok, %Login{}} = Login.build_action([], [])
    end

    test "centralizes help through RR.CLI.parse/1" do
      assert {:ok, %RR.CLI.Help{module: Login}} = CLI.parse(["login", "--help"])
    end

    test "rejects extra args" do
      assert {:error, %ParseError{module: Login, message: message}} =
               Login.build_action([], ["extra"])

      assert message =~ "doesn't take any args"
      assert message =~ "extra"
    end
  end

  describe "execute/1" do
    test "invalid token does not print extra warnings" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_invalid)

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)
      assert :ok = TerminalMock.push_inputs([@hostname, @token_valid])

      assert :ok = Login.execute(%Login{})

      refute TerminalMock.stderr() =~ "To input a valid token, run the command below"
    end

    test "valid token expiring soon prints warning" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_expiring_in_7_days)

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)
      assert :ok = TerminalMock.push_confirms([false])

      assert :ok = Login.execute(%Login{})

      assert TerminalMock.stderr() =~ "warning: rancher token will expire in less than 7 days."
    end

    test "valid token not expiring soon warns about existing config" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_valid)

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)
      assert :ok = TerminalMock.push_confirms([false])

      assert :ok = Login.execute(%Login{})

      assert TerminalMock.stdout() =~ "you already have a valid auth config with description"
    end

    test "existing valid token with transient api error returns error" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_valid)

      expect(RancherMock, :get_token_info, fn _ ->
        {:error, :unknown, "rancher api error - GET #{@hostname}/v3/tokens/token-valid\nboom"}
      end)

      assert {:error, msg} = Login.execute(%Login{})
      assert msg =~ "rancher api error"
    end

    test "login with no existing token and api error does not cache or save" do
      expect(RancherMock, :get_token_info, fn _ ->
        {:error, :unknown, "rancher api error - GET #{@hostname}/v3/tokens/token-valid\nboom"}
      end)

      assert :ok = TerminalMock.push_inputs([@hostname, @token_valid])

      assert {:error, msg} = Login.execute(%Login{})
      assert msg =~ "token validation failed"
      assert TerminalMock.stdout() =~ "rancher hostname"
      assert Settings.get("rancher_hostname") == nil
      assert Settings.get("rancher_token") == nil
      assert :miss == AuthCacheMock.get({@hostname, @token_valid})
    end
  end

  defp get_token_info_mock(%Auth{rancher_token: @token_invalid}) do
    now_ms = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok,
     %{
       description: "old",
       expired: true,
       enabled: true,
       created_ts: now_ms - @day_ms,
       ttl: @day_ms
     }}
  end

  defp get_token_info_mock(%Auth{rancher_token: @token_expiring_in_7_days}) do
    now_ms = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok,
     %{
       description: "expiring",
       expired: false,
       enabled: true,
       created_ts: now_ms,
       ttl: 6 * @day_ms
     }}
  end

  defp get_token_info_mock(%Auth{rancher_token: @token_valid}) do
    now_ms = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {:ok,
     %{
       description: "stable",
       expired: false,
       enabled: true,
       created_ts: now_ms,
       ttl: 10 * @day_ms
     }}
  end
end
