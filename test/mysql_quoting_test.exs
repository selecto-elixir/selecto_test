defmodule Selecto.MySQL.QuotingTest do
  use ExUnit.Case, async: false

  test "MySQL adapter uses backticks for identifiers" do
    # Create a simple domain for testing with proper source structure
    domain = %{
      source: %{
        source_table: "films",
        primary_key: :film_id,
        fields: [:film_id, :title],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string}
        }
      },
      joins: %{}
    }

    # Use Selecto.configure with adapter option
    # Pass empty connection opts since we're only testing SQL generation
    selecto = Selecto.configure(domain, [], adapter: Selecto.DB.MySQL, validate: false)
      |> Selecto.select(["film_id", "title"])

    # Generate SQL
    {sql, _aliases, _params} = Selecto.gen_sql(selecto, [])
    
    # MySQL should use backticks for identifiers
    assert sql =~ "`selecto_root`"
    assert sql =~ "`film_id`"
    assert sql =~ "`title`"
    assert sql =~ "from `films` `selecto_root`"
    
    # Should NOT have double quotes (PostgreSQL style)
    refute sql =~ "\"selecto_root\""
    refute sql =~ "\"film_id\""
    refute sql =~ "\"title\""
  end

  test "PostgreSQL adapter uses double quotes for identifiers" do
    # Create a simple domain for testing with proper source structure
    domain = %{
      source: %{
        source_table: "films",
        primary_key: :film_id,
        fields: [:film_id, :title],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string}
        }
      },
      joins: %{}
    }

    # Use Selecto.configure with PostgreSQL adapter (default)
    # Pass empty connection opts since we're only testing SQL generation  
    selecto = Selecto.configure(domain, [], adapter: Selecto.DB.PostgreSQL, validate: false)
      |> Selecto.select(["film_id", "title"])

    # Generate SQL
    {sql, _aliases, _params} = Selecto.gen_sql(selecto, [])
    
    # PostgreSQL should use double quotes for identifiers
    assert sql =~ "\"selecto_root\""
    assert sql =~ "\"film_id\""
    assert sql =~ "\"title\""
    assert sql =~ "from \"films\" \"selecto_root\""
    
    # Should NOT have backticks (MySQL style)
    refute sql =~ "`selecto_root`"
    refute sql =~ "`film_id`"
    refute sql =~ "`title`"
  end
end