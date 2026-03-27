defmodule RR.Providers.Terminal.Mock do
  @moduledoc false
  @behaviour RR.Providers.Terminal

  @state_key {__MODULE__, :state}

  @impl true
  def info_stdout(message) do
    update_state(fn state ->
      append_stdout(state, render_output(message))
    end)

    :ok
  end

  @impl true
  def info_stderr(message) do
    update_state(fn state ->
      append_stderr(state, render_output(message))
    end)

    :ok
  end

  @impl true
  def error(message) do
    info_stderr(message)
  end

  @impl true
  def input(opts) do
    {answer, label} =
      update_state(fn state ->
        {answer, remaining} = pop_next(state.inputs, :input)
        prompt = render_input_prompt(opts, answer)

        {{answer, prompt}, append_stdout(%{state | inputs: remaining}, prompt)}
      end)

    _ = label
    answer
  end

  @impl true
  def confirm(opts) do
    {answer, prompt} =
      update_state(fn state ->
        {answer, remaining} = pop_next(state.confirms, :confirm)
        prompt = render_confirm_prompt(opts, answer)

        {{answer, prompt}, append_stdout(%{state | confirms: remaining}, prompt)}
      end)

    _ = prompt
    answer
  end

  def reset do
    Process.put(@state_key, initial_state())
    :ok
  end

  def push_inputs(inputs) when is_list(inputs) do
    update_state(fn state ->
      %{state | inputs: state.inputs ++ Enum.map(inputs, &to_string/1)}
    end)

    :ok
  end

  def push_confirms(confirms) when is_list(confirms) do
    update_state(fn state ->
      %{state | confirms: state.confirms ++ confirms}
    end)

    :ok
  end

  def stdout do
    state().stdout
  end

  def stderr do
    state().stderr
  end

  defp render_output(message) do
    IO.iodata_to_binary([IO.ANSI.format(message), ?\n])
  end

  defp render_input_prompt(opts, answer) do
    label = Keyword.fetch!(opts, :label)
    "#{label}: #{answer}\n"
  end

  defp render_confirm_prompt(opts, answer) do
    message =
      opts
      |> Keyword.fetch!(:message)
      |> IO.ANSI.format()
      |> IO.iodata_to_binary()

    suffix = if answer, do: "y", else: "n"
    "#{message} [y/n]: #{suffix}\n"
  end

  defp append_stdout(state, chunk) do
    %{state | stdout: state.stdout <> chunk}
  end

  defp append_stderr(state, chunk) do
    %{state | stderr: state.stderr <> chunk}
  end

  defp pop_next([next | remaining], _kind), do: {next, remaining}

  defp pop_next([], kind) do
    raise ArgumentError, "no scripted #{kind} available for #{inspect(__MODULE__)}"
  end

  defp state do
    Process.get(@state_key, initial_state())
  end

  defp update_state(fun) do
    current = state()

    case fun.(current) do
      {result, next_state} ->
        Process.put(@state_key, next_state)
        result

      next_state ->
        Process.put(@state_key, next_state)
        next_state
    end
  end

  defp initial_state do
    %{stdout: "", stderr: "", inputs: [], confirms: []}
  end
end
