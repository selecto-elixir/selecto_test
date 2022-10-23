defmodule ListableTestWeb.AggregateTestLive do
  use ListableTestWeb, :live_view

  defp listable_domain() do
    domain = ListableTest.listable_domain()

    %{
      domain
      | ## To test group bys..
        required_selected: [
          "name",
          # {:max, "planet[mass]"},
          {:count}
          # {:avg, "planet[radius]"},
        ]
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
        listable:
          Listable.configure(ListableTest.Repo, listable_domain())
          |> Listable.group_by(["name"])
          |> Listable.select([
            "name",
            {:avg, "planets[mass]"},
            {:min, "planets[mass]"},
            {:max, "planets[mass]"}
          ])
      )

    {:noreply, socket}
  end
end
