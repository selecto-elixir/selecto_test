defmodule ListableTestWeb.DetailTestLive do
  use ListableTestWeb, :live_view



  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = assign(socket, listable: Listable.configure(ListableTest.Repo, ListableTest.listable_domain()))
    {:noreply, socket}
  end
end
