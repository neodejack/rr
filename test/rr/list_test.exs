defmodule RR.ListTest do
  use ExUnit.Case, async: true

  import Mox

  alias External.RancherHttpClient.Mock
  alias RR.List

  setup :verify_on_exit!

  describe "run/1" do
    test "renders a table of cluster names and ids" do
      clusters = [
        %{"id" => "c-1", "name" => "dev"},
        %{"id" => "c-9999", "name" => "production"}
      ]

      expect(Mock, :get_clusters, fn ->
        {:ok, clusters}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run([]) end)

      assert output =~ "NAME"
      assert output =~ "ID"
      assert output =~ "dev"
      assert output =~ "production"
      assert output =~ "c-1"
      assert output =~ "c-9999"
    end

    test "renders empty state when no clusters returned" do
      expect(Mock, :get_clusters, fn ->
        {:ok, []}
      end)

      output = ExUnit.CaptureIO.capture_io(fn -> List.run([]) end)

      assert output =~ "NAME"
      assert output =~ "no clusters found"
    end
  end
end
