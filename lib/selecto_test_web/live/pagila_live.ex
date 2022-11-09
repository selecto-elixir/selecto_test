defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use Phoenix.Component

  use SelectoComponents.ViewSelector


  ###

  @impl true
  def mount(_params, _session, socket) do
    selecto = Selecto.configure(SelectoTest.Repo, selecto_domain())

    {:ok, assign(socket, executed: false, applied_view: nil,show_view: false, selecto: selecto ) }
  end

  def film_link(row) do
    {
      Routes.pagila_film_path(SelectoTestWeb.Endpoint, :index, row["film[film_id]"]),
      row["film[title]"]
    }
  end

  def actor_card(assigns) do
    ~H"""
      <div>
        Actor Card for <%= @row["actor_id"] %>
        <%= @row["first_name"] %>
        <%= @row["last_name"] %>
      </div>
    """
  end

  def process_film_card(_selecto, _params) do
    #do we want to handle these in a batch or individually?

  end



  @impl true
  def handle_params(params, _uri, socket) do

    socket =
      assign(socket,
        ### required for selecto components

        view_mode: params["view_mode"] || "detail",
        active_tab: params["active_tab"] || "view",
        per_page: if params["per_page"] do String.to_integer(params["per_page"]) else 30 end,
        page: if params["page"] do String.to_integer(params["page"]) else 0 end,

        aggregate: [],
        group_by: [],
        order_by: [],
        selected: [],
        filters: []
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_show_view", _par, socket) do
    {:noreply, assign(socket, show_view: !socket.assigns.show_view)}
  end


  @doc """
  Test Domain
  """
  defp selecto_domain() do
    %{
      source: SelectoTest.Store.Actor,
      name: "Actors Selecto",
      required_filters: [{"actor_id", {">=", 1}}],
      custom_columns: %{
        "actor_card" => %{
          name: "Actor Card",
          requires_select: ~w(actor_id first_name last_name),
          format: :component,
          component: &actor_card/1,
          process: &process_film_card/2
        }
      },
      joins: [
        film_actors: %{
          name: "Actor-Film Join",
          joins: [
            film: %{
              name: "Film",
              custom_columns: %{
                "film_link" => %{
                  name: "Film Link",
                  requires_select: ["film[film_id]", "film[title]"],
                  format: :link,
                  link_parts: &film_link/1
                },
              }
            }
          ]
        }
      ]
    }
  end

end
