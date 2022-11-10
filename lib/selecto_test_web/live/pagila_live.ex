defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use Phoenix.Component
  import Ecto.Query

  use SelectoComponents.ViewSelector
  ###


  @impl true
  def mount(_params, _session, socket) do
    selecto = Selecto.configure(SelectoTest.Repo, selecto_domain())

    {:ok, assign(socket,  selecto: selecto, show_view: false) }
  end


  @impl true
  def handle_event("toggle_show_view", _par, socket) do
    {:noreply, assign(socket, show_view: !socket.assigns.show_view)}
  end


  @doc """
  Test Domain
  """
  def selecto_domain() do
    %{
      source: SelectoTest.Store.Actor,
      name: "Actors Selecto",
      required_filters: [{"actor_id", {">=", 1}}],
      custom_columns: %{


        #### Example Custom Column Component with subquery and config component
        "actor_card" => %{
          name: "Actor Card",
          requires_select: ~w(actor_id first_name last_name)
           ++ [{:subquery, {:dyn, "actor_films",
            dynamic([{:selecto_root, par}], fragment(
              "array(select row( f.title, f.release_year ) from film f join film_actor af on f.film_id = af.film_id where af.actor_id = ? order by release_year desc limit 5)", par.actor_id
            ))
           }} ],
          format: :component,
          component: &actor_card/1,
          process: &process_film_card/2,
          configure_component: &actor_card_config/1,
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


  def film_link(row) do
    {
      Routes.pagila_film_path(SelectoTestWeb.Endpoint, :index, row["film[film_id]"]),
      row["film[title]"]
    }
  end
  defp actor_card_config(assigns) do
    ~H"""
      <div>
        Actor Card Config!
        <input name={"#{@prefix}[test]"}/>
      </div>
    """
  end

  defp actor_card(assigns) do
    ~H"""
      <div>
        Actor Card for <%= @row["actor_id"] %> (<%= @config["test"] %>)
        <%= @row["first_name"] %>
        <%= @row["last_name"] %>

        <ul>
          <li :for={{title, year} <- @row["actor_films"]}>
            <%= year %>
            <%= title %>
          </li>
        </ul>


      </div>
    """
  end

  def process_film_card(_selecto, _params) do
    #do we want to handle these in a batch or individually?

  end


end
