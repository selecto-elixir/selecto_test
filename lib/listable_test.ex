defmodule ListableTest do
  @moduledoc """
  ListableTest keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def listable_domain() do
    %{
      source: ListableTest.Test.SolarSystem,
      joins: [
        planets: %{
          name: "Planet",
          import_unconfigured_columns: true,
          columns: %{

          },
          joins: [
            satellites: %{
              name: "Natural Satellites",
              joins: []
            }
          ]
        },
      ],
      import_unconfigured_columns: true,
      columns: %{
        name: %{
          name: "Name",
        }
      },
      requires_filters: [{"id", 1}],
      #required_order_by: ["mass"],
      required_selected: [ "id", "name" ],
    }
  end

end
