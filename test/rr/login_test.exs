defmodule RR.LoginTest do
  use ExUnit.Case, async: false

  import Mox

  alias RR.Login
  alias RR.Providers.AuthCache.Mock, as: AuthCacheMock
  alias RR.Providers.Rancher.Mock, as: RancherMock
  alias RR.Providers.SettingsStore.Mock, as: SettingsStoreMock
  alias RR.Services.Auth
  alias RR.Settings

  @day_ms 86_400_000
  @hostname "https://rancher.example"
  @token_invalid "token-old:abc"
  @token_expiring_in_7_days "token-expiring:abc"
  @token_valid "token-valid:abc"

  setup :verify_on_exit!

  setup do
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

  describe "run/1" do
    test "invalid token does not print extra warnings" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_invalid)

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)

      {stderr, _stdout} =
        ExUnit.CaptureIO.with_io([input: "#{@hostname}\n#{@token_valid}\n"], fn ->
          ExUnit.CaptureIO.capture_io(:stderr, fn -> Login.run([]) end)
        end)

      refute stderr =~ "To input a valid token, run the command below"
    end

    test "valid token expiring soon prints warning" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_expiring_in_7_days)

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)

      {stderr, _stdout} =
        ExUnit.CaptureIO.with_io([input: "n\n"], fn ->
          ExUnit.CaptureIO.capture_io(:stderr, fn -> Login.run([]) end)
        end)

      assert stderr =~ "warning: rancher token will expire in less than 7 days."
    end

    test "valid token not expiring soon warns about existing config" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_valid)

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)

      {:ok, stdout} =
        ExUnit.CaptureIO.with_io([input: "n\n"], fn ->
          Login.run([])
        end)

      assert stdout =~ "you already have a valid auth config with description"
    end

    test "existing valid token with transient api error returns error" do
      Settings.put("rancher_hostname", @hostname)
      Settings.put("rancher_token", @token_valid)

      expect(RancherMock, :get_token_info, fn _ ->
        {:error, :unknown, "rancher api error - GET #{@hostname}/v3/tokens/token-valid\nboom"}
      end)

      assert {:error, msg} = Login.run([])
      assert msg =~ "rancher api error"
    end

    test "login with no existing token and api error does not cache or save" do
      expect(RancherMock, :get_token_info, fn _ ->
        {:error, :unknown, "rancher api error - GET #{@hostname}/v3/tokens/token-valid\nboom"}
      end)

      result =
        ExUnit.CaptureIO.capture_io([input: "#{@hostname}\n#{@token_valid}\n"], fn ->
          send(self(), {:result, Login.run([])})
        end)

      assert_received {:result, {:error, msg}}
      assert msg =~ "token validation failed"
      assert result =~ "rancher hostname"
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
