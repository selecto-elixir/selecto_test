defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use SelectoComponents.ViewSelector

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end


  defp selecto_domain() do
    %{
      source: SelectoTest.Store.Actor,
      name: "Actors Selecto",
      required_filters: [{"actor_id", {">=", 1}}],
      joins: [
        film_actors: %{
          name: "Actor-Film Join",
          joins: [
            film: %{
              name: "Film"


            }

          ]

        }

      ]
    }
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    selecto = Selecto.configure(SelectoTest.Repo, selecto_domain())

    socket =
      assign(socket,
        ### Changte to LiveView.JS TODO
        show_view: false,

        ### required for lsitable components
        view_mode: "detail",
        applied_view: "detail",
        active_tab: "view",
        group_by: prep_sels(selecto.set.group_by),
        order_by: prep_sels(selecto.set.order_by),
        selected: prep_sels(selecto.set.selected),
        filters: [],
        aggregate: [],
        per_page: 30,
        page: 0,
        executed: false,
        selecto: selecto
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
