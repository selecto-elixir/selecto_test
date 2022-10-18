defmodule ListableTestWeb.PageLive do
  use ListableTestWeb, :live_view

  use ListableComponentsPetal.ViewSelector



  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    listable = Listable.configure(ListableTest.Repo, ListableTest.listable_domain())
    socket =
      assign(socket,
        view_sel: "detail",
        group_by: listable.set.group_by,
        order_by: listable.set.order_by,
        selected: listable.set.selected,
        listable: listable
      )
    {:noreply, socket}
  end
end
