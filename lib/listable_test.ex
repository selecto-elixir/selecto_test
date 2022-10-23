defmodule ListableTest do
  @moduledoc """
  ListableTest keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def listable_domain() do
    %{
      ### Source is the first table in the query
      source: ListableTest.Test.SolarSystem,
      name: "Solar System",
      joins: [
        planets: %{
          name: "Planet",
          import_unconfigured_columns: true,
          columns: %{
            ### special column definitions
            name: %{
              name: "Name",
            },
            id: %{
              name: "Planet ID",
              id: "planet_id"
            }
          },
          filters:
            %{
              ### Special filter definitions
              is_earth: %{
                type: :boolean,
                true: ["planet[name]", "earth"],
                false: ["planet[name]", {"!=", "earth"}],
              },
              special: %{
                name: "Special Filter (Should be overridden...)"

              }
            },
          joins: [
            satellites: %{
              name: "Natural Satellites",

            },
            nonassoctest: %{ ###TODO extra joins
              not_assoc: true,
              name: "Test Join",

              join_table: :tablename, ## atom - for Schema module, string for table name
              join_clause: [
                {}

              ],
              columns: %{},
              filters: %{}
            }
          ]
        }
      ],
      import_unconfigured_columns: true, #TODO
      columns:
        %{
          ### special column definitions
        },
      filters:
        %{
          ### Special filter definitions
          special: %{
            name: "Special Filter (Solar System)"

          }
        },
      required_filters: [
        {"id", 1},
       # {"name", {"!=", "Rats"}},
       # {"planets[name]", {"!=", "Mars"}},
       # {"satellites[name]", nil},
       # {"planets[mass]", {"between", 1.0, 100000.0}},
       # {"planets[atmosphere]", :not_true},
       # {:or, [
       #   {"planet_id", {"<", 3}},
       #   {"planet_id", {">", 6}},
       # ]}
      ],
      # required_order_by: ["mass"],
      required_selected: ["id", "name", "planets[name]"]
    }
  end
end
