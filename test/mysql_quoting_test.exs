defmodule Selecto.MySQL.QuotingTest do
  use ExUnit.Case, async: false

  # Skip MySQL-dependent tests by default
  @moduletag :mysql_integration

  test "MySQL adapter only quotes identifiers when necessary" do
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
    
    # MySQL should NOT quote simple identifiers that don't need it
    assert sql =~ "selecto_root"
    assert sql =~ "film_id"
    assert sql =~ "title"
    assert sql =~ "from films selecto_root"
    
    # Should NOT have unnecessary quotes
    refute sql =~ "`selecto_root`"
    refute sql =~ "`film_id`"
    refute sql =~ "`title`"
    refute sql =~ "\"selecto_root\""
    refute sql =~ "\"film_id\""
    refute sql =~ "\"title\""
  end

  test "PostgreSQL adapter only quotes identifiers when necessary" do
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
    
    # PostgreSQL should NOT quote simple identifiers that don't need it
    assert sql =~ "selecto_root"
    assert sql =~ "film_id"
    assert sql =~ "title"
    assert sql =~ "from films selecto_root"
    
    # Should NOT have unnecessary quotes
    refute sql =~ "\"selecto_root\""
    refute sql =~ "\"film_id\""
    refute sql =~ "\"title\""
    refute sql =~ "`selecto_root`"
    refute sql =~ "`film_id`"
    refute sql =~ "`title`"
  end
  
  test "MySQL adapter quotes special identifiers with backticks" do
    # Create domain with identifiers that need quoting
    domain = %{
      source: %{
        source_table: "user-data",  # Contains hyphen - needs quoting
        primary_key: :id,
        fields: [:id, :"select", :"order-by"],  # Reserved words and special chars
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          select: %{type: :string},  # Reserved word
          "order-by": %{type: :string}  # Contains hyphen
        }
      },
      joins: %{}
    }

    selecto = Selecto.configure(domain, [], adapter: Selecto.DB.MySQL, validate: false)
      |> Selecto.select(["id", "select", "order-by"])

    {sql, _aliases, _params} = Selecto.gen_sql(selecto, [])
    
    # MySQL should use backticks for special identifiers
    assert sql =~ "`user-data`"  # Table with hyphen
    assert sql =~ "`select`"     # Reserved word
    assert sql =~ "`order-by`"   # Field with hyphen
    
    # Regular identifier shouldn't be quoted
    refute sql =~ "`id`"
  end
  
  test "PostgreSQL adapter quotes special identifiers with double quotes" do
    # Create domain with identifiers that need quoting
    domain = %{
      source: %{
        source_table: "user-data",  # Contains hyphen - needs quoting
        primary_key: :id,
        fields: [:id, :"select", :"order-by"],  # Reserved words and special chars
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          select: %{type: :string},  # Reserved word
          "order-by": %{type: :string}  # Contains hyphen
        }
      },
      joins: %{}
    }

    selecto = Selecto.configure(domain, [], adapter: Selecto.DB.PostgreSQL, validate: false)
      |> Selecto.select(["id", "select", "order-by"])

    {sql, _aliases, _params} = Selecto.gen_sql(selecto, [])
    
    # PostgreSQL should use double quotes for special identifiers
    assert sql =~ "\"user-data\""  # Table with hyphen
    assert sql =~ "\"select\""     # Reserved word
    assert sql =~ "\"order-by\""   # Field with hyphen
    
    # Regular identifier shouldn't be quoted
    refute sql =~ "\"id\""
  end
end