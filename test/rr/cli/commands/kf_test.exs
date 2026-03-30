defmodule RR.CLI.Commands.KfTest do
  use ExUnit.Case, async: false

  import Mox

  alias RR.CLI
  alias RR.CLI.Commands.Kf
  alias RR.CLI.ParseError
  alias RR.Providers.AuthCache.Mock, as: AuthCacheMock
  alias RR.Providers.Rancher.Mock, as: RancherMock
  alias RR.Providers.SettingsStore.Mock, as: SettingsStoreMock
  alias RR.Providers.Terminal.Mock, as: TerminalMock
  alias RR.Services.Clusters.Cluster
  alias RR.Settings

  setup :verify_on_exit!

  setup do
    TerminalMock.reset()
    store = start_supervised!({Agent, fn -> %{} end}, id: make_ref())

    stub(SettingsStoreMock, :read, fn ->
      Agent.get(store, & &1)
    end)

    stub(SettingsStoreMock, :write, fn config ->
      Agent.update(store, fn _ -> config end)
      :ok
    end)

    stub(AuthCacheMock, :get, fn _key -> {:hit, true} end)
    stub(AuthCacheMock, :put, fn _key, _valid? -> :ok end)
    stub(AuthCacheMock, :clear, fn -> :ok end)

    rr_home = Path.join(System.tmp_dir!(), "rr-kf-test-#{System.unique_integer([:positive])}")
    previous_rr_home = System.get_env("RR_HOME")
    System.put_env("RR_HOME", rr_home)

    on_exit(fn ->
      if previous_rr_home do
        System.put_env("RR_HOME", previous_rr_home)
      else
        System.delete_env("RR_HOME")
      end

      File.rm_rf(rr_home)
    end)

    Settings.put("rancher_hostname", "https://rancher.example")
    Settings.put("rancher_token", "token-123:abc")

    :ok
  end

  describe "build_action/2" do
    test "returns an action for cluster and switches" do
      assert {:ok, %Kf{cluster: "dev", sh?: true, new?: true}} =
               Kf.build_action([sh: true, new: true], ["dev"])
    end

    test "centralizes help through RR.CLI.parse/1" do
      assert {:ok, %RR.CLI.Invocation{module: RR.CLI, action: %RR.CLI.HelpAction{module: Kf}}} =
               CLI.parse(["kf", "--help"])
    end

    test "rejects missing cluster" do
      assert {:error, %ParseError{module: Kf, message: "you didn't provide <cluster_name_substring>"}} =
               Kf.build_action([], [])
    end

    test "rejects more than one cluster" do
      assert {:error, %ParseError{module: Kf, message: message}} = Kf.build_action([], ["dev", "prod"])
      assert IO.iodata_to_binary(message) =~ "you provided more than one clusters: dev, prod"
    end
  end

  describe "execute/1" do
    test "fetches kubeconfig and renders shell export for parsed action" do
      expect(RancherMock, :get_clusters, fn _auth ->
        {:ok, [%{"id" => "c-1", "name" => "dev-cluster"}]}
      end)

      expect(RancherMock, :get_kubeconfig, fn _auth, %Cluster{id: "c-1", name: "dev-cluster"} = cluster ->
        {:ok, %{cluster | kubeconfig: "apiVersion: v1\nclusters: []\n"}}
      end)

      assert :ok = Kf.execute(%Kf{cluster: "dev", new?: true, sh?: true})

      assert TerminalMock.stdout() =~ "export KUBECONFIG="
      assert TerminalMock.stdout() =~ "dev-cluster"
      assert TerminalMock.stderr() =~ "new kubeconfig is saved to"
      assert File.exists?(Path.join([System.get_env("RR_HOME"), "kubeconfigs", "dev-cluster"]))
    end
  end
end
