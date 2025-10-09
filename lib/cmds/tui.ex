defmodule RR.Cmds.Tui.List do
  def init(children, last_state) do
    %{values: Enum.map(children, & &1.value), selected: last_state[:selected]}
  end

  def handle_event(_, %{"key" => "ArrowDown"}, %{values: values} = state) do
    index = Enum.find_index(values, &(&1 == state.selected))
    value = if index, do: Enum.at(values, index + 1) || hd(values), else: hd(values)
    {:noreply, %{state | selected: value}}
  end

  def handle_event(_, %{"key" => "ArrowUp"}, %{values: values} = state) do
    index = Enum.find_index(values, &(&1 == state.selected))
    first = hd(Enum.reverse(values))
    value = if index, do: Enum.at(values, index - 1) || first, else: first
    {:noreply, %{state | selected: value}}
  end

  def handle_event(_, %{"key" => "\r"}, state) do
    {{:change, %{value: state.selected}}, state}
  end

  def handle_event(_, _, state), do: {:noreply, state}

  def handle_modifiers(flags, state) do
    if state.selected == Keyword.get(flags, :value) do
      [selected: true]
    else
      []
    end
  end
end

defmodule RR.Cmds.Tui.SelectCluster do
  use Breeze.View

  def mount(opts, term) do
    term = Map.put_new(term, :receiver, Keyword.fetch!(opts, :receiver))
    term = term |> assign(extra_help: nil) |> assign(clusters: Keyword.fetch!(opts, :clusters))

    {:ok, term}
  end

  def render(assigns) do
    ~H"""
    <box id="base">
    <.list br-change="selected" id="list-1">
      <:item :for={cluster <- @clusters} value={cluster.id}>{cluster.name}</:item>
    </.list>
      <box style="border" id="help">press up/down to select. press enter to confirm. press q to quit</box>
      <box :if={@extra_help}>{@extra_help}</box>
    </box>
    """
  end

  attr(:id, :string, required: true)
  attr(:rest, :global)

  slot :item do
    attr(:value, :string, required: true)
  end

  def list(assigns) do
    ~H"""
      <box focusable implicit={RR.Cmds.Tui.List} id={@id} {@rest}>
          <box
            :for={item <- @item}
            value={item.value}
            style="selected:bg-24 selected:text-0 focus:selected:text-7 focus:selected:bg-4"
          >{render_slot(item, %{})}</box>
      </box>
    """
  end

  def handle_info(_, term) do
    {:noreply, term}
  end

  def handle_event("selected", %{value: nil}, term) do
    {:noreply, assign(term, extra_help: "you did not select any value")}
  end

  def handle_event("selected", %{value: value}, term) do
    send(term.receiver, {:selected, value})
    {:noreply, term}
  end

  def handle_event(_, %{"key" => "q"}, term) do
    send(term.receiver, {:quit})
    {:noreply, term}
  end

  def handle_event(_, _, term) do
    {:noreply, term}
  end
end
