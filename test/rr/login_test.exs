defmodule RR.LoginTest do
  use ExUnit.Case, async: false

  import Mox

  alias External.Config.Mock, as: ConfigMock
  alias External.RancherHttpClient.Mock, as: RancherMock
  alias RR.Config
  alias RR.Config.Auth
  alias RR.Login

  @day_ms 86_400_000
  @hostname "https://rancher.example"
  @token_invalid "token-old:abc"
  @token_expiring_in_7_days "token-expiring:abc"
  @token_valid "token-valid:abc"

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
    test "invalid token does not print extra warnings" do
      Config.put_auth({@hostname, @token_invalid})

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)

      {stderr, _stdout} =
        ExUnit.CaptureIO.with_io([input: "#{@hostname}\n#{@token_valid}\n"], fn ->
          ExUnit.CaptureIO.capture_io(:stderr, fn -> Login.run([]) end)
        end)

      refute stderr =~ "To input a valid token, run the command below"
    end

    test "valid token expiring soon prints warning" do
      Config.put_auth({@hostname, @token_expiring_in_7_days})

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)

      {stderr, _stdout} =
        ExUnit.CaptureIO.with_io([input: "n\n"], fn ->
          ExUnit.CaptureIO.capture_io(:stderr, fn -> Login.run([]) end)
        end)

      assert stderr =~ "warning: rancher token will expire in less than 7 days."
    end

    test "valid token not expiring soon warns about existing config" do
      Config.put_auth({@hostname, @token_valid})

      expect(RancherMock, :get_token_info, 2, &get_token_info_mock/1)

      {:ok, stdout} =
        ExUnit.CaptureIO.with_io([input: "n\n"], fn ->
          Login.run([])
        end)

      assert stdout =~ "you already have a valid auth config with description"
    end

    test "existing valid token with transient api error prints error and exits" do
      Config.put_auth({@hostname, @token_valid})

      expect(RancherMock, :get_token_info, fn _ ->
        {:error, :unknown, "rancher api error - GET #{@hostname}/v3/tokens/token-valid\nboom"}
      end)

      stderr =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          assert_raise RuntimeError, ~r/rancher api error/, fn ->
            Login.run([])
          end
        end)

      assert stderr =~ "rancher api error - GET"
    end

    test "login with no existing token and api error does not cache or save" do
      expect(RancherMock, :get_token_info, fn _ ->
        {:error, :unknown, "rancher api error - GET #{@hostname}/v3/tokens/token-valid\nboom"}
      end)

      {stderr, _stdout} =
        ExUnit.CaptureIO.with_io([input: "#{@hostname}\n#{@token_valid}\n"], fn ->
          ExUnit.CaptureIO.capture_io(:stderr, fn ->
            assert_raise RuntimeError, ~r/token validation failed/, fn ->
              Login.run([])
            end
          end)
        end)

      assert stderr =~ "token validation failed"
      assert Config.get_auth() == {nil, nil}

      case :ets.whereis(:rr_auth_cache) do
        :undefined -> :ok
        tid -> assert :ets.lookup(tid, {@hostname, @token_valid}) == []
      end
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

  defp clear_auth_cache do
    case :ets.whereis(:rr_auth_cache) do
      :undefined -> :ok
      _tid -> :ets.delete(:rr_auth_cache)
    end
  end
end
