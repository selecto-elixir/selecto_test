defmodule ListableTestWeb.PageLive do
  use ListableTestWeb, :live_view



  defp listable_domain() do
    %{
      source: ListableTest.Test.Planet,
      joins: [
        :solar_system,
        :satellites,
      ],
      requires_filters: [{"solar_system[id]", 1}],
      #required_order_by: [ {:desc, "mass"} ],
      #required_selected: ["name", "solar_system[name]"]

      ## To test group bys..
      required_selected: [ "solar_system[name]", {"max", "mass"}, {"count"}, {"avg", "radius"} ],
      required_group_by: ["solar_system[name]"]
    }
  end


  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket }
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, listable: Listable.configure(ListableTest.Repo, listable_domain()))
    {:noreply, socket}
  end


end
