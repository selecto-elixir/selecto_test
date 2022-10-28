defmodule SelectoTesttWeb.AggregateTestLive do
  use SelectoTesttWeb, :live_view

  defp selecto_domain() do
    domain = SelectoTestt.selecto_domain()

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
        selecto:
          selecto.configure(SelectoTestt.Repo, selecto_domain())
          |> selecto.group_by([{:extract, "inserted_at", "year"}])
          |> selecto.select([
            {:extract, "inserted_at", "year"},

            {:avg, "planets[mass]"},
            {:min, "planets[mass]"},
            {:max, "planets[mass]"}
          ])
      )

    {:noreply, socket}
  end
end
