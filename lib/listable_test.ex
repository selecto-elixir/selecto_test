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
              name: "Name"
            }
          },
          filters:
            %{
              ### Special filter definitions
              "is_earth" => %{
                type: :boolean,
                true: ["planet[name]", "earth"],
                false: ["planet[name]", {"!=", "earth"}],

              }
            },
          joins: [
            satellites: %{
              name: "Natural Satellites",
              joins: []
            }
          ]
        }
      ],
      import_unconfigured_columns: true,
      columns:
        %{
          ### special column definitions
        },
      filters:
        %{
          ### Special filter definitions
        },
      required_filters: [
        {"id", 1},
        {"name", {"!=", "Rats"}},
        {"planets[name]", {"!=", "Mars"}},
        {"satellites[name]", nil},
        {"planets[mass]", {"between", 1.0, 100000.0}},
        {"planets[atmosphere]", :not_true},
        #{:or, [
        #  {"planents[id]", {"<", 3}},
        #  {"planents[id]", {">", 6}},
        #]}
      ],
      # required_order_by: ["mass"],
      required_selected: ["id", "name", "planets[name]"]
    }
  end
end
