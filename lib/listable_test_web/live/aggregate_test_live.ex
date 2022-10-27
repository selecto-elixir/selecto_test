defmodule ListableTestWeb.AggregateTestLive do
  use ListableTestWeb, :live_view

  defp listable_domain() do
    domain = ListableTest.listable_domain()

    %{
      domain
      | ## To test group bys..
        required_selected: [ ]
        # required_group_by: ["solar_system[name]"]
    }
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      assign(socket,
        detail_links: false,
        listable:
          Listable.configure(ListableTest.Repo, listable_domain())
          |> Listable.group_by([{:extract, "inserted_at", "year"}])
          |> Listable.select([
            {:extract, "inserted_at", "year"},

            {:avg, "planets[mass]"},
            {:min, "planets[mass]"},
            {:max, "planets[mass]"}
          ])
      )

    {:noreply, socket}
  end
end
