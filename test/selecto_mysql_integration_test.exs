defmodule SelectoMySQLIntegrationTest do
  use ExUnit.Case, async: false
  
  alias Selecto.DB.MySQL
  alias Selecto
  
  @mysql_config [
    hostname: "localhost",
    port: 3306,
    username: "selecto_user",
    password: "selecto_password",
    database: "selecto_test"
  ]
  
  setup_all do
    # Use local MySQL installation instead of Docker
    IO.puts("Connecting to local MySQL installation...")
    
    # Create test database and schema
    setup_mysql_test_db()
    
    on_exit(fn ->
      cleanup_mysql_test_data()
    end)
    
    :ok
  end
  
  # No longer needed - using local MySQL
  # defp start_mysql_docker removed
  
  # No longer needed - local MySQL is already running
  # defp wait_for_mysql removed
  
  defp test_mysql_connection do
    case MySQL.connect(@mysql_config) do
      {:ok, conn} ->
        MySQL.disconnect(conn)
        :ok
      {:error, _} ->
        :error
    end
  end
  
  defp setup_mysql_test_db do
    {:ok, conn} = MySQL.connect(@mysql_config)
    
    # Create comprehensive test schema
    create_mysql_schema(conn)
    insert_mysql_test_data(conn)
    
    MySQL.disconnect(conn)
    
    IO.puts("MySQL test database schema and data created")
  end
  
  defp create_mysql_schema(conn) do
    # Create actors table
    MySQL.execute(conn, """
      CREATE TABLE IF NOT EXISTS actors (
        actor_id INT AUTO_INCREMENT PRIMARY KEY,
        first_name VARCHAR(45) NOT NULL,
        last_name VARCHAR(45) NOT NULL,
        last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    """, [], [])
    
    # Create films table with advanced features
    MySQL.execute(conn, """
      CREATE TABLE IF NOT EXISTS films (
        film_id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(128) NOT NULL,
        description TEXT,
        release_year INT,
        rating ENUM('G', 'PG', 'PG-13', 'R', 'NC-17') DEFAULT 'G',
        rental_duration INT NOT NULL DEFAULT 3,
        rental_rate DECIMAL(4,2) NOT NULL DEFAULT 4.99,
        length INT,
        replacement_cost DECIMAL(5,2) NOT NULL DEFAULT 19.99,
        special_features JSON,
        last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FULLTEXT(title, description)
      )
    """, [], [])
    
    # Create film_actors junction table
    MySQL.execute(conn, """
      CREATE TABLE IF NOT EXISTS film_actors (
        actor_id INT NOT NULL,
        film_id INT NOT NULL,
        last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (actor_id, film_id),
        FOREIGN KEY (actor_id) REFERENCES actors(actor_id) ON DELETE CASCADE,
        FOREIGN KEY (film_id) REFERENCES films(film_id) ON DELETE CASCADE
      )
    """, [], [])
    
    # Create categories table
    MySQL.execute(conn, """
      CREATE TABLE IF NOT EXISTS categories (
        category_id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(25) NOT NULL,
        last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    """, [], [])
    
    # Create film_categories junction table
    MySQL.execute(conn, """
      CREATE TABLE IF NOT EXISTS film_categories (
        film_id INT NOT NULL,
        category_id INT NOT NULL,
        last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (film_id, category_id),
        FOREIGN KEY (film_id) REFERENCES films(film_id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
      )
    """, [], [])
  end
  
  defp insert_mysql_test_data(conn) do
    # Clear existing data (ignore errors for non-existent tables)
    MySQL.execute(conn, "SET FOREIGN_KEY_CHECKS = 0", [], [])
    # Delete in reverse foreign key order
    MySQL.execute(conn, "DELETE FROM film_actors", [], []) |> ignore_error()
    MySQL.execute(conn, "DELETE FROM film_categories", [], []) |> ignore_error()
    MySQL.execute(conn, "DELETE FROM films", [], []) |> ignore_error()
    MySQL.execute(conn, "DELETE FROM actors", [], []) |> ignore_error()
    MySQL.execute(conn, "DELETE FROM categories", [], []) |> ignore_error()
    MySQL.execute(conn, "SET FOREIGN_KEY_CHECKS = 1", [], [])
    
    # Insert actors
    MySQL.execute(conn, """
      INSERT INTO actors (first_name, last_name) VALUES
      ('John', 'Doe'),
      ('Jane', 'Smith'),
      ('Robert', 'Johnson'),
      ('Emily', 'Davis'),
      ('Michael', 'Wilson')
    """, [], [])
    
    # Insert categories
    MySQL.execute(conn, """
      INSERT INTO categories (name) VALUES
      ('Action'),
      ('Comedy'),
      ('Drama'),
      ('Horror'),
      ('Sci-Fi')
    """, [], [])
    
    # Insert films with JSON features
    MySQL.execute(conn, """
      INSERT INTO films (title, description, release_year, rating, rental_duration, rental_rate, length, replacement_cost, special_features) VALUES
      ('Epic Adventure', 'A thrilling epic adventure movie with stunning visuals', 2020, 'PG-13', 7, 5.99, 140, 24.99, '["Action Scenes", "Commentary", "Behind the Scenes"]'),
      ('Comedy Gold', 'Hilarious comedy that will make you laugh out loud', 2019, 'PG', 3, 3.99, 95, 19.99, '["Deleted Scenes", "Bloopers", "Cast Commentary"]'),
      ('Dark Drama', 'Intense psychological drama exploring human nature', 2021, 'R', 5, 4.99, 120, 22.99, '["Director Commentary", "Behind Scenes", "Alternate Ending"]'),
      ('Space Odyssey', 'Mind-bending science fiction journey through space', 2020, 'PG-13', 7, 6.99, 180, 27.99, '["Commentary", "Making Of", "Deleted Scenes", "Visual Effects"]'),
      ('Horror Night', 'Spine-chilling horror experience that will haunt you', 2022, 'R', 3, 4.99, 90, 20.99, '["Commentary", "Alternate Ending", "Behind Scenes"]')
    """, [], [])
    
    # Insert film-actor relationships
    MySQL.execute(conn, """
      INSERT INTO film_actors (actor_id, film_id) VALUES
      (1, 1), (2, 1), (3, 1),
      (2, 2), (4, 2),
      (3, 3), (5, 3),
      (1, 4), (4, 4), (5, 4),
      (2, 5), (3, 5)
    """, [], [])
    
    # Insert film-category relationships
    MySQL.execute(conn, """
      INSERT INTO film_categories (film_id, category_id) VALUES
      (1, 1), (1, 3),
      (2, 2),
      (3, 3),
      (4, 5),
      (5, 4)
    """, [], [])
  end
  
  defp cleanup_mysql_test_data do
    # Clean up test data from local MySQL
    {:ok, conn} = MySQL.connect(@mysql_config)
    
    # Drop test tables in reverse order of dependencies
    tables = [
      "film_categories", "categories", "films"
    ]
    
    for table <- tables do
      MySQL.execute(conn, "DROP TABLE IF EXISTS #{table}", [], [])
    end
    
    MySQL.disconnect(conn)
    IO.puts("MySQL test data cleaned up")
  end
  
  defp ignore_error({:ok, result}), do: {:ok, result}
  defp ignore_error({:error, _}), do: :ok
  
  # Define domain configuration for films
  defp films_domain_config do
    %{
      source: %{
        source_table: "films",
        primary_key: :film_id,
        fields: [:film_id, :title, :description, :release_year, :rating, :rental_duration, :rental_rate, :length, :replacement_cost, :special_features, :last_update],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :text},
          release_year: %{type: :integer},
          rating: %{type: :string},
          rental_duration: %{type: :integer},
          rental_rate: %{type: :decimal},
          length: %{type: :integer},
          replacement_cost: %{type: :decimal},
          special_features: %{type: :json},
          last_update: %{type: :utc_datetime}
        },
        associations: %{
          actors: %{
            queryable: :actors,
            field: :actors,
            owner_key: :film_id,
            related_key: :film_id,
            through: :film_actors
          },
          categories: %{
            queryable: :categories,
            field: :categories,
            owner_key: :film_id,
            related_key: :film_id,
            through: :film_categories
          }
        }
      },
      schemas: %{
        actors: %{
          source_table: "actors",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name, :last_name, :last_update],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string},
            last_update: %{type: :utc_datetime}
          },
          associations: %{}
        },
        categories: %{
          source_table: "categories", 
          primary_key: :category_id,
          fields: [:category_id, :name, :last_update],
          redact_fields: [],
          columns: %{
            category_id: %{type: :integer},
            name: %{type: :string},
            last_update: %{type: :utc_datetime}
          },
          associations: %{}
        }
      },
      name: "Films",
      joins: %{}
    }
  end
  
  # Create a simple MySQL connection wrapper for Selecto
  defmodule MySQLRepo do
    def query(sql, params, opts \\ []) do
      config = [
        hostname: "localhost",
        port: 3306,
        username: "selecto_user",
        password: "selecto_password",
        database: "selecto_test"
      ]
      
      {:ok, conn} = Selecto.DB.MySQL.connect(config)
      
      result = case Selecto.DB.MySQL.execute(conn, sql, params, opts) do
        {:ok, %{rows: rows, columns: columns, num_rows: num_rows}} ->
          {:ok, %{rows: rows, columns: columns, num_rows: num_rows}}
        error ->
          error
      end
      
      Selecto.DB.MySQL.disconnect(conn)
      result
    end
    
    def query!(sql, params, opts \\ []) do
      case query(sql, params, opts) do
        {:ok, result} -> result
        {:error, error} -> raise "Database error: #{inspect(error)}"
      end
    end
  end
  
  describe "Basic Selecto Query Building and Execution with MySQL" do
    test "builds and executes simple SELECT queries" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select(["title", "rating", "rental_rate"])
      |> Selecto.filter({"rating", "PG-13"})
      |> Selecto.order_by([{"title", :asc}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 3
      assert "title" in columns
      assert "rating" in columns
      assert "rental_rate" in columns
      
      # Should return Epic Adventure and Space Odyssey (both PG-13)
      assert length(rows) == 2
      
      # Verify ordering by title
      titles = Enum.map(rows, fn row ->
        Enum.at(row, Enum.find_index(columns, &(&1 == "title")))
      end)
      assert titles == ["Epic Adventure", "Space Odyssey"]
    end
    
    test "builds and executes queries with aggregation" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select([{:count, "*"}, "rating"])
      |> Selecto.group_by(["rating"])
      |> Selecto.order_by([{"rating", :asc}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 2
      
      # Verify we have count and rating columns
      count_index = Enum.find_index(columns, &(&1 == "count"))
      rating_index = Enum.find_index(columns, &(&1 == "rating"))
      
      assert count_index != nil
      assert rating_index != nil
      
      # Verify we have proper aggregation results
      counts = Enum.map(rows, &Enum.at(&1, count_index))
      assert Enum.all?(counts, &(is_integer(&1) and &1 > 0))
    end
    
    test "builds and executes queries with complex filters" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select(["title", "length", "rental_rate"])
      |> Selecto.filter([
        {"length", {:gt, 100}},
        {"rental_rate", {:lt, 6.0}}
      ])
      |> Selecto.order_by([{"rental_rate", :desc}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 3
      
      # Verify all returned films meet the criteria
      length_index = Enum.find_index(columns, &(&1 == "length"))
      rate_index = Enum.find_index(columns, &(&1 == "rental_rate"))
      
      for row <- rows do
        length = Enum.at(row, length_index)
        rate = Enum.at(row, rate_index)
        assert length > 100
        assert rate < 6.0
      end
    end
    
    test "builds and executes queries with LIMIT and OFFSET" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select(["title", "release_year"])
      |> Selecto.order_by([{"title", :asc}])
      |> Selecto.limit(2)
      |> Selecto.offset(1)
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 2
      assert length(rows) == 2
      
      # Should return 2nd and 3rd films alphabetically by title
      title_index = Enum.find_index(columns, &(&1 == "title"))
      titles = Enum.map(rows, &Enum.at(&1, title_index))
      
      # Verify they are in alphabetical order
      assert titles == Enum.sort(titles)
    end
  end
  
  describe "Advanced SQL Features with MySQL through Selecto" do
    test "generates and executes SQL with JSON operations" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      # Generate SQL to inspect the query
      {sql, params} = selecto
      |> Selecto.select(["title", "special_features"])
      |> Selecto.filter({"title", "Epic Adventure"})
      |> Selecto.to_sql()
      
      # Verify MySQL-specific SQL generation
      assert sql =~ "SELECT"
      assert sql =~ "films"
      assert sql =~ "WHERE"
      assert sql =~ "title"
      
      # Execute the query through our adapter
      {:ok, conn} = MySQL.connect(@mysql_config)
      {:ok, result} = MySQL.execute(conn, sql, params, [])
      MySQL.disconnect(conn)
      
      assert result.num_rows == 1
      assert "title" in result.columns
      assert "special_features" in result.columns
      
      [[title, features]] = result.rows
      assert title == "Epic Adventure"
      assert is_binary(features) # JSON comes back as string from MySQL
    end
    
    test "generates MySQL-specific SQL with proper parameter placeholders" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      {sql, params} = selecto
      |> Selecto.select(["title", "rating"])
      |> Selecto.filter([
        {"rating", "PG-13"},
        {"rental_rate", {:gt, 5.0}}
      ])
      |> Selecto.to_sql()
      
      # MySQL uses ? placeholders, not $1, $2
      assert sql =~ "?"
      refute sql =~ "$1"
      refute sql =~ "$2"
      
      # Should have proper parameters
      assert length(params) == 2
      assert "PG-13" in params
      assert 5.0 in params
    end
    
    test "generates SQL with proper MySQL identifier quoting" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      {sql, _params} = selecto
      |> Selecto.select(["title", "release_year"])
      |> Selecto.to_sql()
      
      # MySQL uses backticks for identifiers
      assert sql =~ "`films`"
      assert sql =~ "`title`"
      assert sql =~ "`release_year`"
      
      # Should not use double quotes (PostgreSQL style)
      refute sql =~ "\"films\""
      refute sql =~ "\"title\""
    end
  end
  
  describe "MySQL-Specific Features through Selecto" do
    test "works with ENUM columns" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select(["title", "rating"])
      |> Selecto.filter({"rating", {:in, ["G", "PG", "PG-13"]}})
      |> Selecto.order_by([{"rating", :asc}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      
      # Verify all ratings are from the allowed ENUM values
      rating_index = Enum.find_index(columns, &(&1 == "rating"))
      ratings = Enum.map(rows, &Enum.at(&1, rating_index))
      
      for rating <- ratings do
        assert rating in ["G", "PG", "PG-13"]
      end
    end
    
    test "handles DECIMAL columns correctly" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select(["title", "rental_rate", "replacement_cost"])
      |> Selecto.filter({"rental_rate", {:between, [4.0, 6.0]}})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      
      rate_index = Enum.find_index(columns, &(&1 == "rental_rate"))
      cost_index = Enum.find_index(columns, &(&1 == "replacement_cost"))
      
      for row <- rows do
        rate = Enum.at(row, rate_index)
        cost = Enum.at(row, cost_index)
        
        # Verify decimal values are returned as numbers
        assert is_number(rate) or match?(%Decimal{}, rate)
        assert is_number(cost) or match?(%Decimal{}, cost)
        # Convert to float for comparison
        rate_val = if is_number(rate), do: rate, else: Decimal.to_float(rate)
        assert rate_val >= 4.0 and rate_val <= 6.0
      end
    end
    
    test "executes complex analytical queries" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      # Test aggregate functions with grouping
      result = selecto
      |> Selecto.select([
        "rating",
        {:avg, "rental_rate"},
        {:max, "length"},
        {:min, "replacement_cost"},
        {:count, "*"}
      ])
      |> Selecto.group_by(["rating"])
      |> Selecto.order_by([{"rating", :asc}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 5
      
      # Verify aggregate results
      for row <- rows do
        [rating, avg_rate, max_length, min_cost, count] = row
        
        assert is_binary(rating)
        assert is_number(avg_rate)
        assert is_integer(max_length)
        assert is_number(min_cost)
        assert is_integer(count) and count > 0
      end
    end
  end
  
  describe "Error Handling and Edge Cases" do
    test "handles empty result sets gracefully" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select(["title"])
      |> Selecto.filter({"title", "Nonexistent Movie"})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert rows == []
      assert columns == ["title"]
    end
    
    test "handles NULL values correctly" do
      # First insert a film with NULL description
      {:ok, conn} = MySQL.connect(@mysql_config)
      
      MySQL.execute(conn, """
        INSERT INTO films (title, description, rating) 
        VALUES ('NULL Test', NULL, 'G')
      """, [], [])
      
      MySQL.disconnect(conn)
      
      # Now query it with Selecto
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      result = selecto
      |> Selecto.select(["title", "description"])
      |> Selecto.filter({"title", "NULL Test"})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert length(rows) == 1
      
      [[title, description]] = rows
      assert title == "NULL Test"
      assert description == nil
    end
    
    test "generates valid SQL for complex filter combinations" do
      domain = films_domain_config()
      selecto = Selecto.configure(domain, @mysql_config, adapter: Selecto.DB.MySQL)
      
      {sql, params} = selecto
      |> Selecto.select(["title", "rating", "length"])
      |> Selecto.filter([
        {"rating", {:in, ["PG", "PG-13", "R"]}},
        {"length", {:between, [90, 180]}},
        {"rental_rate", {:gt, 3.99}}
      ])
      |> Selecto.order_by([{"rating", :asc}, {"title", :desc}])
      |> Selecto.to_sql()
      
      # Verify SQL is properly formed
      assert sql =~ "SELECT"
      assert sql =~ "WHERE"
      assert sql =~ "ORDER BY"
      assert sql =~ "IN"
      assert sql =~ "BETWEEN"
      
      # Execute to ensure it's valid MySQL SQL
      {:ok, conn} = MySQL.connect(@mysql_config)
      {:ok, _result} = MySQL.execute(conn, sql, params, [])
      MySQL.disconnect(conn)
    end
  end
end