defmodule SelectoTest do
  @moduledoc """
  SelectoTest keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def selecto_domain() do
    %{
      ### Source is the first table in the query
      source: SelectoTest.Test.SolarSystem,
      name: "Solar System",
      ### TODO to be used for contructing links
      domain_data: %{
        domain: "planets"
      },
      joins: [
        planets: %{
          name: "Planet",
          import_unconfigured_columns: true,
          columns: %{
            ### special column definitions
            name: %{
              name: "Name"
            },
            id: %{
              name: "Planet ID",
              id: "planet_id",
              ### TODO !
              also_select: "planets[name]"
              # link: ~P"/:domain/planets/:id" # tap tap tap
            },
            mass: %{
              # yes this is redic
              format: fn
                v when is_float(v) -> :erlang.float_to_binary(v, decimals: 3)
                _ -> ""
              end
            }
          },
          filters: %{
            ### Special filter definitions
            is_earth: %{
              type: :boolean,
              true: ["planet[name]", "earth"],
              false: ["planet[name]", {"!=", "earth"}]
            },
            special: %{
              name: "Special Filter (Should be overridden...)"
            }
          },
          joins: [
            satellites: %{
              name: "Satellites"
            },
            ### TODO extra joins
            nonassoctest: %{
              not_assoc: true,
              name: "Test Join",
              ## atom - for Schema module, string for table name
              join_table: :tablename,
              join_clause: [
                {}
              ],
              columns: %{},
              filters: %{}
            }
          ]
        }
      ],
      # TODO
      import_unconfigured_columns: true,
      columns:
        %{
          ### special column definitions
        },
      filters: %{
        ### Special filter definitions
        special: %{
          name: "Special Filter (Solar System)"
        }
      },
      required_filters: [
        {"id", [1, 2, 3, 4, 5, 6]}
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
