defmodule SelectoTestWeb.AggregateTestLive do
  use SelectoTestWeb, :live_view

  defp selecto_domain() do
    domain = SelectoTest.selecto_domain()

    %{
      domain
      | ## To test group bys..
        required_selected: []
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
        selecto:
          Selecto.configure(SelectoTest.Repo, selecto_domain())
          |> Selecto.group_by(
              [
                {
                  :rollup,
                  [{:extract, "inserted_at", "year"}]
                }
              ]
            )
          |> Selecto.select([
            {:extract, "inserted_at", "year"},
            {:avg, "planets[mass]"},
            {:min, "planets[mass]"},
            {:max, "planets[mass]"}
          ])
      )

    {:noreply, socket}
  end
end
