defmodule ListableTestWeb.PageLive do
  use ListableTestWeb, :live_view

  use ListableComponentsPetal.ViewSelector

  defp listable_domain() do
    %{
      source: ListableTest.Test.Planet,
      joins: [
        :solar_system,
        :satellites
      ],
      requires_filters: [{"solar_system[id]", 1}],
      required_order_by: [{:desc, "mass"}],
      required_selected: [ "id", "name" ]
    }
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    listable = Listable.configure(ListableTest.Repo, listable_domain())
    socket =
      assign(socket,
        view_sel: "aggregate",
        group_by: [],
        selected: [],
        listable: listable
      )
    {:noreply, socket}
  end
end
