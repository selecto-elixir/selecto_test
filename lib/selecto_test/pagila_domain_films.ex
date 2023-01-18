defmodule SelectoTest.PagilaDomainFilms do
  import Phoenix.Component
  use SelectoTestWeb, :verified_routes
  import SelectoComponents.Components.Common
  @behaviour SelectoComponents.SavedViews

  ### TODO - fix agg filter appluy for film ratings
  import Ecto.Query

  def get_view(name, context) do
    q = from v in SelectoTest.SavedView,
      where: ^context == v.context,
      where:  ^name == v.name
    SelectoTest.Repo.one( q )
  end

  def save_view(name, context, params) do
    case get_view(name, context) do
      nil -> SelectoTest.Repo.insert!(%SelectoTest.SavedView{name: name, context: context, params: params})
      view -> update_view(view, params)
    end
  end

  def update_view(view, params) do
    {:ok, view} = SelectoTest.SavedView.changeset(view, %{params: params})
      |> SelectoTest.Repo.update()
    view
  end

  def get_view_names(context) do
    q = from v in SelectoTest.SavedView,
      select: v.name,
      where: ^context == v.context

    SelectoTest.Repo.all( q )
  end

  def decode_view(view) do
    ### give params to use for view
    view.params
  end


  def domain() do
    ### customer info, payments and rentals
    %{
      source: SelectoTest.Store.Film,
      name: "Film",
      default_selected: ["title"],
      default_order_by: ["title"],
      default_group_by: ["release_year"],
      default_aggregate: [{"film_id", %{"format" => "count"}}],
      filters: %{

      },
      custom_columns: %{
        "film_link" => %{
          name: "Film Link",
          requires_select: ["film_id", "title"],
          format: :link,
          link_parts: fn {id, title} -> {~p[/pagila/film/#{id}], title} end
        },
        "fulltext" => %{
          field: "fulltext",
          type: :tsvector,
          name: "Title and Description Search",
          make_filter: true
        }
      },
      joins: %{
        # categories: %{
        #   name: "Categories",
        #   type: :tag
        # },
        language: %{
          name: "Film Language",
          ## TODO Lookup type means that local table as an ID to a table that provides a 'dimension' that is
          type: :dimension,
          # the interesting data. So in this case, film has language[name], we will never care about language_id
          # We do not want to give 2 language ID columns to pick from, so will skip the remote, and skip date/update
          # info from the remote table. Lookup_value is the only col we will add from remote table (can be List to add more than one)
          dimension: :name
        }
      }
    }
  end
end
