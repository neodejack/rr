defmodule RR.Providers.Terminal.MockTest do
  use ExUnit.Case, async: true

  alias RR.Providers.Terminal.Mock

  setup do
    Mock.reset()
  end

  test "collects stdout and stderr transcripts" do
    assert :ok = Mock.info_stdout(["hello", " world"])
    assert :ok = Mock.info_stderr("warning")
    assert :ok = Mock.error("boom")

    assert Mock.stdout() == "hello world\n"
    assert Mock.stderr() == "warning\nboom\n"
  end

  test "replays scripted input and confirmation answers into stdout" do
    assert :ok = Mock.push_inputs(["https://rancher.example", "token-valid:abc"])
    assert :ok = Mock.push_confirms([false])

    assert Mock.input(label: "rancher hostname") == "https://rancher.example"

    assert Mock.input(label: "rancher token (in the form of token-xxxx:xxxxxx)", secret: true) ==
             "token-valid:abc"

    assert Mock.confirm(message: ["overwrite existing config?"]) == false

    assert Mock.stdout() =~ "rancher hostname: https://rancher.example"
    assert Mock.stdout() =~ "rancher token (in the form of token-xxxx:xxxxxx): token-valid:abc"
    assert Mock.stdout() =~ "overwrite existing config? [y/n]: n"
  end

  test "reset clears transcripts and scripted answers" do
    assert :ok = Mock.info_stdout("hello")
    assert :ok = Mock.push_inputs(["answer"])

    assert :ok = Mock.reset()

    assert Mock.stdout() == ""
    assert Mock.stderr() == ""

    assert_raise ArgumentError, ~r/no scripted input/, fn ->
      Mock.input(label: "rancher hostname")
    end
  end
end
