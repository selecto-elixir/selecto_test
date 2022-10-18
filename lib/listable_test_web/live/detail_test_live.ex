defmodule ListableTestWeb.DetailTestLive do
  use ListableTestWeb, :live_view

  defp listable_domain() do
    %{
      source: ListableTest.Test.Planet,
      joins: [
        :solar_system,
        :satellites
      ],
      requires_filters: [{"solar_system[id]", 1}],
      required_order_by: [{:desc, "mass"}],
      required_selected: [
        {:upper, "name", "NAME"},
        "mass",
        {:lower, "solar_system[name]", "SOLNAME"},
        {:literal, "literal", "HI"}
        # {:literal, "littest_num", 1010}
      ]
    }
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = assign(socket, listable: Listable.configure(ListableTest.Repo, listable_domain()))
    {:noreply, socket}
  end
end
