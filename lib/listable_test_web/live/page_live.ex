defmodule ListableTestWeb.PageLive do
  use ListableTestWeb, :live_view

  use ListableComponentsTailwind.ViewSelector

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    listable = Listable.configure(ListableTest.Repo, ListableTest.listable_domain())

    socket =
      assign(socket,
        show_view: false,  ### Changte to LiveView.JS TODO

        ### required for lsitable components
        view_mode: "detail",
        active_tab: "view",
        group_by: prep_sels(listable.set.group_by),
        order_by: prep_sels(listable.set.order_by),
        selected: prep_sels(listable.set.selected),
        filters: [],
        aggregate: [],
        listable: listable
      )

    {:noreply, socket}
  end

  # handle this better. TODO
  defp prep_sels(list) do
    list |> Enum.map(fn item -> {UUID.uuid4(), item, %{}} end)
  end

  @impl true
  def handle_event("toggle_show_view", _par, socket) do
    {:noreply, assign(socket, show_view: !socket.assigns.show_view)}
  end
end
