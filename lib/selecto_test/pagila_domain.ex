defmodule SelectoTest.PagilaDomain do

  import Phoenix.Component

  def domain() do
    %{
      source: SelectoTest.Store.Actor,
      name: "Actors Selecto",
      required_filters: [{"actor_id", {">=", 1}}],
      filters: %{
        "actor_has_ratings" => %{
          name: "Actor Has Ratings",
          component: &actor_ratings/1,
          type: :component,
          apply: &actor_ratings_apply/2
        }
      },
      custom_columns: %{
        #### Example Custom Column Component with subquery and config component
        "actor_card" => %{
          name: "Actor Card",
          ## Can also be a plain list or function which takes the column configuration struct and returns list
          requires_select: fn conf ->
            limit =
              case Map.get(conf, "limit") do
                nil -> 5
                "" -> 5
                x when is_binary(x) -> String.to_integer(x)
              end

            # TODO fix bug where if this col is selexted 2x with different paremters, the second squashes the first
            ~w(actor_id first_name last_name) ++
              [
                {:subquery, "array(select row( f.title, f.release_year )
                      from film f join film_actor af on f.film_id = af.film_id
                      where af.actor_id = selecto_root.actor_id
                      order by release_year desc
                      limit ^SelectoParam^)", [limit]}
              ]
          end,
          format: :component,
          component: &actor_card/1,
          configure_component: &actor_card_config/1,

          # TODO
          process: &process_film_card/2
        }
      },
      joins: [
        film_actors: %{
          name: "Actor-Film Join",
          joins: [
            film: %{
              joins: [
                language: %{
                  name: "Film Language",
                  ## TODO Lookup type means that local table as an ID to a table that provides a 'lookup_value' that is
                  type: :lookup,
                  # the interesting data. So in this case, film has language[name], we will never care about language_id
                  # We do not want to give 2 language ID columns to pick from, so will skip the remote, and skip date/update
                  # info from the remote table. Lookup_value is the only col we will add from remote table (can be List to add more than one)
                  lookup_value: :name,
                  lookup: {:select, :language_id, :language_id, :name}
                }
              ],
              name: "Film",
              custom_columns: %{
                "film_link" => %{
                  name: "Film Link",
                  requires_select: ["film[film_id]", "film[title]"],
                  format: :link,
                  link_parts: &film_link/1
                }
              }
            }
          ]
        }
      ]
    }
  end

  def actor_ratings_apply(selecto, f) do
    ratings = f["ratings"]

    {"actor_id",
     {:subquery, :in,
      "(select actor_id from film_actor fa join film f on fa.film_id = f.film_id where f.rating = ANY(^SelectoParam^))",
      [ratings]}}
  end

  def actor_ratings(assigns) do
    ~H"""
    <div>
      Actor Ratings!
      <label :for={v <- ~w(G PG PG-13 R NC-17)}>
        <input
          type="checkbox"
          name={"filters[#{@uuid}][ratings][]"}
          value={v}
          checked={Enum.member?(Map.get(@valmap, "ratings", []), v)}
        />
        <%= v %>
      </label>
    </div>
    """
  end

  def film_link(row) do
    {id, title} = row

    {
      # ~p[/pagila/film/#{ row[ "film[film_id]" ]}],
      Routes.pagila_film_path(SelectoTestWeb.Endpoint, :index, id),
      title
    }
  end

  defp actor_card_config(assigns) do
    ~H"""
    <div>
      Actor Card Show # of Most Recent Films:
      <input type="number" name={"#{@prefix}[limit]"} value={Map.get(@config, "limit", 5)} />
    </div>
    """
  end

  defp actor_card(assigns) do
    ~H"""
    <div>
      <%= with {actor_id, first_name, last_name, actor_films} <- @row do %>
        Actor Card for <%= actor_id %> (<%= @config["limit"] %>) <%= first_name %>
        <%= last_name %>

        <ul>
          <li :for={{title, year} <- actor_films}>
            <%= year %>
            <%= title %>
          </li>
        </ul>
      <% end %>
    </div>
    """
  end

  def process_film_card(_selecto, _params) do
    # do we want to handle these in a batch or individually?
  end

end
