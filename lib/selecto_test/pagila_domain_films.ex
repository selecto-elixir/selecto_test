defmodule SelectoTest.PagilaDomainFilms do
  use SelectoTestWeb, :verified_routes
  use SelectoTest.SavedViewContext

  ### TODO - fix agg filter appluy for film ratings

  def domain() do
    ### customer info, payments and rentals
    %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description, :release_year, :language_id, :rental_duration, :rental_rate, :length, :replacement_cost, :rating, :special_features],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :string},
          release_year: %{type: :integer},
          language_id: %{type: :integer},
          rental_duration: %{type: :integer},
          rental_rate: %{type: :decimal},
          length: %{type: :integer},
          replacement_cost: %{type: :decimal},
          rating: %{type: :string},
          special_features: %{type: {:array, :string}}
        },
        associations: %{
          language: %{
            queryable: :language,
            field: :language,
            owner_key: :language_id,
            related_key: :language_id
          }
        }
      },
      schemas: %{
        language: %{
          source_table: "language",
          primary_key: :language_id,
          fields: [:language_id, :name],
          redact_fields: [],
          columns: %{
            language_id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        }
      },
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
