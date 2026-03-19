defmodule RR.Config.SchemaTest do
  use ExUnit.Case, async: true

  alias RR.Config.Schema

  describe "detect_version/1" do
    test "treats missing schema_version as legacy version 0" do
      assert {:ok, 0} = Schema.detect_version(%{"profiles" => %{}})
    end

    test "accepts the current explicit schema version" do
      current_version = Schema.current_version()

      assert {:ok, ^current_version} =
               Schema.detect_version(%{"schema_version" => current_version, "profiles" => %{}})
    end

    test "rejects newer schema versions" do
      assert {:error, "config schema 2 is newer than this rr release supports"} =
               Schema.detect_version(%{"schema_version" => 2})
    end

    test "rejects non-integer schema versions" do
      assert {:error, "config schema_version must be a non-negative integer"} =
               Schema.detect_version(%{"schema_version" => "1"})
    end
  end
end
