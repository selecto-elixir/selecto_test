defmodule MySQLDockerIntegrationTest do
  use ExUnit.Case, async: false
  
  alias Selecto.DB.MySQL
  
  @mysql_config [
    hostname: "localhost",
    port: 3306,
    username: "selecto_user",
    password: "selecto_password",
    database: "selecto_test"
  ]
  
  setup_all do
    # Start MySQL Docker container for testing
    start_mysql_docker()
    
    # Wait for MySQL to be ready
    wait_for_mysql()
    
    # Create test database and schema
    setup_mysql_test_db()
    
    on_exit(fn ->
      cleanup_mysql_docker()
    end)
    
    :ok
  end
  
  defp start_mysql_docker do
    # Stop any existing container
    System.cmd("docker", ["stop", "selecto_mysql_test"], stderr_to_stdout: true)
    System.cmd("docker", ["rm", "selecto_mysql_test"], stderr_to_stdout: true)
    
    # Start fresh MySQL container
    {output, exit_code} = System.cmd("docker", [
      "run", "-d",
      "--name", "selecto_mysql_test",
      "-p", "3306:3306",
      "-e", "MYSQL_ROOT_PASSWORD=root_password",
      "-e", "MYSQL_USER=selecto_user",
      "-e", "MYSQL_PASSWORD=selecto_password", 
      "-e", "MYSQL_DATABASE=selecto_test",
      "mysql:8.0",
      "--character-set-server=utf8mb4",
      "--collation-server=utf8mb4_unicode_ci"
    ], stderr_to_stdout: true)
    
    if exit_code == 0 do
      IO.puts("MySQL Docker container started successfully")
    else
      IO.puts("Failed to start MySQL container: #{output}")
      flunk("Could not start MySQL Docker container")
    end
  end
  
  defp wait_for_mysql do
    IO.puts("Waiting for MySQL to be ready...")
    
    # Wait up to 60 seconds for MySQL to be ready
    Enum.reduce_while(1..60, :not_ready, fn attempt, _acc ->
      case test_mysql_connection() do
        :ok -> 
          IO.puts("MySQL is ready after #{attempt} seconds")
          # Give MySQL extra time to fully initialize
          IO.puts("Waiting additional 5 seconds for MySQL to fully initialize...")
          Process.sleep(5000)
          {:halt, :ready}
        :error ->
          if attempt == 60 do
            flunk("MySQL failed to start within 60 seconds")
          else
            Process.sleep(1000)
            {:cont, :not_ready}
          end
      end
    end)
  end
  
  defp test_mysql_connection do
    case MySQL.connect(@mysql_config) do
      {:ok, conn} ->
        try do
          MySQL.disconnect(conn)
        rescue
          _ -> :ok  # Ignore disconnect errors during testing
        end
        :ok
      {:error, _} ->
        :error
    end
  end
  
  defp setup_mysql_test_db do
    # Retry connection and schema creation
    case retry_with_backoff(fn -> create_schema_with_connection() end, 3) do
      :ok -> IO.puts("MySQL schema setup completed successfully")
      {:error, reason} -> flunk("Schema creation failed after retries: #{inspect(reason)}")
    end
  end
  
  defp create_schema_with_connection do
    case MySQL.connect(@mysql_config) do
      {:ok, conn} ->
        IO.puts("Connected to MySQL, creating comprehensive schema...")
        result = create_comprehensive_schema(conn)
        try do
          MySQL.disconnect(conn)
        rescue
          _ -> :ok
        end
        result
      {:error, reason} ->
        IO.puts("Failed to connect to MySQL: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp create_comprehensive_schema(conn) do
    try do
      # Drop tables if they exist (in reverse order due to foreign keys)
      MySQL.execute(conn, "SET FOREIGN_KEY_CHECKS = 0", [], [])
      MySQL.execute(conn, "DROP TABLE IF EXISTS rentals", [], [])
      MySQL.execute(conn, "DROP TABLE IF EXISTS film_actor", [], [])
      MySQL.execute(conn, "DROP TABLE IF EXISTS film_category", [], [])
      MySQL.execute(conn, "DROP TABLE IF EXISTS films", [], [])
      MySQL.execute(conn, "DROP TABLE IF EXISTS actors", [], [])
      MySQL.execute(conn, "DROP TABLE IF EXISTS categories", [], [])
      MySQL.execute(conn, "DROP TABLE IF EXISTS customers", [], [])
      MySQL.execute(conn, "SET FOREIGN_KEY_CHECKS = 1", [], [])
      
      # Create actors table
      case MySQL.execute(conn, """
        CREATE TABLE IF NOT EXISTS actors (
          actor_id INT AUTO_INCREMENT PRIMARY KEY,
          first_name VARCHAR(45) NOT NULL,
          last_name VARCHAR(45) NOT NULL,
          birth_date DATE,
          active BOOLEAN DEFAULT TRUE,
          rating DECIMAL(3,2) DEFAULT 0.0,
          bio JSON,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_name (last_name, first_name),
          INDEX idx_active (active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> IO.puts("Actors table created successfully")
        {:error, reason} -> throw({:error, {:actors_table, reason}})
      end
      
      # Create films table
      case MySQL.execute(conn, """
        CREATE TABLE films (
          film_id INT AUTO_INCREMENT PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          description TEXT,
          release_year INT,
          rating ENUM('G','PG','PG-13','R','NC-17') DEFAULT 'G',
          rental_duration TINYINT DEFAULT 3,
          rental_rate DECIMAL(4,2) DEFAULT 4.99,
          length SMALLINT,
          replacement_cost DECIMAL(5,2) DEFAULT 19.99,
          special_features JSON,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_title (title),
          INDEX idx_year (release_year),
          INDEX idx_rating (rating),
          FULLTEXT KEY idx_search (title, description)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> IO.puts("Films table created successfully")
        {:error, reason} -> throw({:error, {:films_table, reason}})
      end
      
      # Create categories table
      case MySQL.execute(conn, """
        CREATE TABLE categories (
          category_id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(25) NOT NULL UNIQUE,
          description TEXT,
          active BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> IO.puts("Categories table created successfully")
        {:error, reason} -> throw({:error, {:categories_table, reason}})
      end
      
      # Create customers table
      case MySQL.execute(conn, """
        CREATE TABLE customers (
          customer_id INT AUTO_INCREMENT PRIMARY KEY,
          store_id TINYINT NOT NULL DEFAULT 1,
          first_name VARCHAR(45) NOT NULL,
          last_name VARCHAR(45) NOT NULL,
          email VARCHAR(50),
          active BOOLEAN DEFAULT TRUE,
          create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
          last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> IO.puts("Customers table created successfully")
        {:error, reason} -> throw({:error, {:customers_table, reason}})
      end
      
      # Create junction tables
      case MySQL.execute(conn, """
        CREATE TABLE film_actor (
          actor_id INT NOT NULL,
          film_id INT NOT NULL,
          role_name VARCHAR(100),
          PRIMARY KEY (actor_id, film_id),
          FOREIGN KEY (actor_id) REFERENCES actors(actor_id),
          FOREIGN KEY (film_id) REFERENCES films(film_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> IO.puts("Film_actor junction table created successfully")
        {:error, reason} -> throw({:error, {:film_actor_table, reason}})
      end
      
      case MySQL.execute(conn, """
        CREATE TABLE film_category (
          film_id INT NOT NULL,
          category_id INT NOT NULL,
          PRIMARY KEY (film_id, category_id),
          FOREIGN KEY (film_id) REFERENCES films(film_id),
          FOREIGN KEY (category_id) REFERENCES categories(category_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> IO.puts("Film_category junction table created successfully")
        {:error, reason} -> throw({:error, {:film_category_table, reason}})
      end
      
      case MySQL.execute(conn, """
        CREATE TABLE rentals (
          rental_id INT AUTO_INCREMENT PRIMARY KEY,
          rental_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          film_id INT NOT NULL,
          customer_id INT NOT NULL,
          return_date DATETIME,
          status ENUM('rented', 'returned', 'overdue', 'lost') DEFAULT 'rented',
          FOREIGN KEY (film_id) REFERENCES films(film_id),
          FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> IO.puts("Rentals table created successfully")
        {:error, reason} -> throw({:error, {:rentals_table, reason}})
      end
      
      # Insert test data
      insert_comprehensive_test_data(conn)
      
    catch
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp insert_comprehensive_test_data(conn) do
    # Insert actors
    case MySQL.execute(conn, """
      INSERT INTO actors (first_name, last_name, birth_date, active, rating, bio) VALUES
      ('John', 'Doe', '1980-01-15', true, 4.5, '{"awards": ["Oscar"], "notable_films": ["Epic Adventure"]}'),
      ('Jane', 'Smith', '1975-03-22', true, 4.8, '{"awards": ["Golden Globe"], "notable_films": ["Comedy Gold"]}'),
      ('Robert', 'Johnson', '1985-07-30', true, 4.2, '{"awards": [], "notable_films": ["Dark Drama"]}'),
      ('Emily', 'Davis', '1990-11-05', true, 4.7, '{"awards": ["SAG Award"], "notable_films": ["Space Odyssey"]}'),
      ('Michael', 'Wilson', '1978-09-12', false, 3.9, '{"awards": [], "notable_films": ["Horror Night"]}')
    """, [], []) do
      {:ok, _} -> IO.puts("Actors inserted successfully")
      {:error, reason} -> throw({:error, {:actors_insert, reason}})
    end
    
    # Insert categories
    case MySQL.execute(conn, """
      INSERT INTO categories (name, description, active) VALUES
      ('Action', 'High-energy action and adventure films', true),
      ('Comedy', 'Humorous and light-hearted entertainment', true),
      ('Drama', 'Character-driven dramatic narratives', true),
      ('Horror', 'Suspenseful and frightening content', true),
      ('Sci-Fi', 'Science fiction and futuristic themes', true)
    """, [], []) do
      {:ok, _} -> IO.puts("Categories inserted successfully")
      {:error, reason} -> throw({:error, {:categories_insert, reason}})
    end
    
    # Insert films with JSON features
    case MySQL.execute(conn, """
      INSERT INTO films (title, description, release_year, rating, rental_duration, rental_rate, length, replacement_cost, special_features) VALUES
      ('Epic Adventure', 'A thrilling epic adventure movie with stunning visuals', 2020, 'PG-13', 7, 5.99, 140, 24.99, '["Action Scenes", "Commentary", "Behind the Scenes"]'),
      ('Comedy Gold', 'Hilarious comedy that will make you laugh out loud', 2019, 'PG', 3, 3.99, 95, 19.99, '["Deleted Scenes", "Bloopers", "Cast Commentary"]'),
      ('Dark Drama', 'Intense psychological drama exploring human nature', 2021, 'R', 5, 4.99, 120, 22.99, '["Director Commentary", "Behind Scenes", "Alternate Ending"]'),
      ('Space Odyssey', 'Mind-bending science fiction journey through space', 2020, 'PG-13', 7, 6.99, 180, 27.99, '["Commentary", "Making Of", "Deleted Scenes", "Visual Effects"]'),
      ('Horror Night', 'Spine-chilling horror experience that will haunt you', 2022, 'R', 3, 4.99, 90, 20.99, '["Commentary", "Alternate Ending", "Behind Scenes"]')
    """, [], []) do
      {:ok, _} -> IO.puts("Films inserted successfully")
      {:error, reason} -> throw({:error, {:films_insert, reason}})
    end
    
    # Insert customers
    case MySQL.execute(conn, """
      INSERT INTO customers (store_id, first_name, last_name, email, active) VALUES
      (1, 'Alice', 'Customer', 'alice@example.com', true),
      (1, 'Bob', 'Renter', 'bob@example.com', true),
      (2, 'Carol', 'Viewer', 'carol@example.com', false)
    """, [], []) do
      {:ok, _} -> IO.puts("Customers inserted successfully")
      {:error, reason} -> throw({:error, {:customers_insert, reason}})
    end
    
    # Insert film-actor relationships
    case MySQL.execute(conn, """
      INSERT INTO film_actor (actor_id, film_id, role_name) VALUES
      (1, 1, 'Hero'), (2, 1, 'Sidekick'), (3, 1, 'Villain'),
      (2, 2, 'Lead Comic'), (4, 2, 'Supporting'),
      (3, 3, 'Protagonist'), (5, 3, 'Antagonist'),
      (1, 4, 'Space Captain'), (4, 4, 'Engineer'), (5, 4, 'Alien'),
      (2, 5, 'Final Girl'), (3, 5, 'Monster')
    """, [], []) do
      {:ok, _} -> IO.puts("Film-actor relationships inserted successfully")
      {:error, reason} -> throw({:error, {:film_actor_insert, reason}})
    end
    
    # Insert film-category relationships
    case MySQL.execute(conn, """
      INSERT INTO film_category (film_id, category_id) VALUES
      (1, 1), (1, 3),  -- Epic Adventure: Action + Drama
      (2, 2),          -- Comedy Gold: Comedy
      (3, 3),          -- Dark Drama: Drama
      (4, 5),          -- Space Odyssey: Sci-Fi
      (5, 4)           -- Horror Night: Horror
    """, [], []) do
      {:ok, _} -> IO.puts("Film-category relationships inserted successfully")
      {:error, reason} -> throw({:error, {:film_category_insert, reason}})
    end
    
    # Insert some rental data
    case MySQL.execute(conn, """
      INSERT INTO rentals (film_id, customer_id, return_date, status) VALUES
      (1, 1, '2024-01-20 15:30:00', 'returned'),
      (2, 1, NULL, 'rented'),
      (3, 2, '2024-01-18 12:00:00', 'returned'),
      (4, 2, NULL, 'rented'),
      (5, 3, NULL, 'overdue')
    """, [], []) do
      {:ok, _} -> IO.puts("Rental data inserted successfully")
      :ok
      {:error, reason} -> throw({:error, {:rentals_insert, reason}})
    end
  end
  
  defp retry_with_backoff(func, retries) when retries > 0 do
    case func.() do
      :ok -> :ok
      {:error, reason} ->
        IO.puts("Attempt failed: #{inspect(reason)}. Retrying in 2 seconds...")
        Process.sleep(2000)
        retry_with_backoff(func, retries - 1)
    end
  end
  
  defp retry_with_backoff(_func, 0) do
    {:error, :max_retries_exceeded}
  end
  
  defp cleanup_mysql_docker do
    # Gracefully stop and remove container
    {_, _} = System.cmd("docker", ["stop", "selecto_mysql_test"], stderr_to_stdout: true)
    {_, _} = System.cmd("docker", ["rm", "selecto_mysql_test"], stderr_to_stdout: true)
    IO.puts("MySQL Docker container cleaned up")
  end
  
  # Connection setup for each test
  setup do
    {:ok, conn} = MySQL.connect(@mysql_config)
    
    on_exit(fn -> 
      try do
        MySQL.disconnect(conn)
      rescue
        _ -> :ok
      end
    end)
    
    {:ok, conn: conn}
  end
  
  describe "MySQL connection and basic operations" do
    test "basic connection and simple query", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, "SELECT 1 as test_value", [], [])
      
      assert result.num_rows == 1
      assert result.columns == ["test_value"]
      assert result.rows == [[1]]
    end
    
    test "query with parameters", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT actor_id, first_name, last_name 
        FROM actors 
        WHERE active = ? AND rating >= ?
        ORDER BY rating DESC
      """, [true, 4.0], [])
      
      assert result.num_rows >= 3
      assert "actor_id" in result.columns
      assert "first_name" in result.columns
      assert "last_name" in result.columns
    end
  end
  
  describe "MySQL data types and features" do
    test "JSON data operations", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT title, JSON_EXTRACT(special_features, '$[0]') as first_feature
        FROM films 
        WHERE JSON_LENGTH(special_features) > 2
        ORDER BY title
      """, [], [])
      
      assert result.num_rows >= 2
      assert "title" in result.columns
      assert "first_feature" in result.columns
      
      # Verify JSON extraction worked
      for [title, feature] <- result.rows do
        assert is_binary(title)
        assert feature != nil
      end
    end
    
    test "ENUM and DECIMAL data types", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT title, rating, rental_rate, replacement_cost
        FROM films
        WHERE rating IN ('PG', 'PG-13', 'R')
        ORDER BY rental_rate DESC
      """, [], [])
      
      assert result.num_rows >= 4
      
      for [title, rating, rental_rate, replacement_cost] <- result.rows do
        assert is_binary(title)
        assert rating in ["PG", "PG-13", "R"]
        assert is_number(rental_rate) or match?(%Decimal{}, rental_rate)
        assert is_number(replacement_cost) or match?(%Decimal{}, replacement_cost)
      end
    end
    
    test "DATE and TIMESTAMP operations", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT 
          first_name,
          last_name,
          birth_date,
          YEAR(birth_date) as birth_year,
          created_at,
          DATE(created_at) as created_date
        FROM actors
        WHERE birth_date IS NOT NULL
        ORDER BY birth_date
      """, [], [])
      
      assert result.num_rows >= 3
      assert "birth_year" in result.columns
      assert "created_date" in result.columns
      
      # Verify date operations
      for row <- result.rows do
        birth_year = Enum.at(row, Enum.find_index(result.columns, &(&1 == "birth_year")))
        assert is_integer(birth_year)
        assert birth_year >= 1970 and birth_year <= 2000
      end
    end
  end
  
  describe "Advanced MySQL query features" do
    test "Complex JOINs with multiple tables", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT 
          f.title,
          a.first_name,
          a.last_name,
          fa.role_name,
          c.name as category_name
        FROM films f
        INNER JOIN film_actor fa ON f.film_id = fa.film_id
        INNER JOIN actors a ON fa.actor_id = a.actor_id
        LEFT JOIN film_category fc ON f.film_id = fc.film_id
        LEFT JOIN categories c ON fc.category_id = c.category_id
        WHERE f.rating = 'PG-13'
        ORDER BY f.title, a.last_name
      """, [], [])
      
      assert result.num_rows >= 4  # Epic Adventure and Space Odyssey have multiple actors
      assert "title" in result.columns
      assert "role_name" in result.columns
      assert "category_name" in result.columns
    end
    
    test "Aggregate functions with GROUP BY and HAVING", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT 
          rating,
          COUNT(*) as film_count,
          AVG(rental_rate) as avg_rate,
          MAX(length) as max_length
        FROM films
        GROUP BY rating
        HAVING COUNT(*) >= 1
        ORDER BY avg_rate DESC
      """, [], [])
      
      assert result.num_rows >= 3  # We have PG, PG-13, R ratings
      assert "film_count" in result.columns
      assert "avg_rate" in result.columns
      assert "max_length" in result.columns
      
      # Verify aggregation results
      for row <- result.rows do
        [_rating, count, avg_rate, max_length] = row
        assert is_integer(count) and count >= 1
        assert is_number(avg_rate)
        assert is_integer(max_length)
      end
    end
    
    test "Subqueries and EXISTS clauses", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT f.title, f.rental_rate
        FROM films f
        WHERE f.rental_rate > (
          SELECT AVG(rental_rate) FROM films
        )
        AND EXISTS (
          SELECT 1 FROM film_actor fa 
          WHERE fa.film_id = f.film_id
        )
        ORDER BY f.rental_rate DESC
      """, [], [])
      
      assert result.num_rows >= 1  # Films with above-average rates that have actors
      assert "title" in result.columns
      assert "rental_rate" in result.columns
    end
    
    test "Full-text search capabilities", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        SELECT title, description,
               MATCH(title, description) AGAINST('adventure' IN NATURAL LANGUAGE MODE) as relevance
        FROM films
        WHERE MATCH(title, description) AGAINST('adventure' IN NATURAL LANGUAGE MODE)
        ORDER BY relevance DESC
      """, [], [])
      
      assert result.num_rows >= 1  # Should find "Epic Adventure"
      assert "relevance" in result.columns
      
      # Verify relevance scores
      for row <- result.rows do
        relevance = Enum.at(row, Enum.find_index(result.columns, &(&1 == "relevance")))
        assert is_number(relevance) and relevance > 0
      end
    end
  end
  
  describe "MySQL-specific optimizations and performance" do
    test "EXPLAIN query plans", %{conn: conn} do
      {:ok, result} = MySQL.execute(conn, """
        EXPLAIN SELECT * FROM films WHERE rating = 'PG-13'
      """, [], [])
      
      assert result.num_rows >= 1
      assert "table" in result.columns or "Table" in result.columns
    end
    
    test "prepared statements", %{conn: conn} do
      {:ok, prepared} = MySQL.prepare(conn, "get_actor_films", """
        SELECT a.first_name, a.last_name, f.title
        FROM actors a
        INNER JOIN film_actor fa ON a.actor_id = fa.actor_id
        INNER JOIN films f ON fa.film_id = f.film_id
        WHERE a.actor_id = ?
      """)
      
      # Execute with different parameters
      {:ok, result1} = MySQL.execute_prepared(conn, prepared, [1], [])
      {:ok, result2} = MySQL.execute_prepared(conn, prepared, [2], [])
      
      assert length(result1.rows) >= 0
      assert length(result2.rows) >= 0
      assert result1.columns == result2.columns
    end
    
    test "pagination with LIMIT and OFFSET", %{conn: conn} do
      page_size = 3
      
      for page <- 0..2 do
        offset = page * page_size
        
        {:ok, result} = MySQL.execute(conn, """
          SELECT actor_id, first_name, last_name
          FROM actors
          ORDER BY actor_id
          LIMIT ? OFFSET ?
        """, [page_size, offset], [])
        
        assert length(result.rows) >= 0
        assert length(result.rows) <= page_size
        
        if result.num_rows > 0 do
          assert "actor_id" in result.columns
        end
      end
    end
  end
  
  describe "MySQL transactions and consistency" do
    test "transaction commit", %{conn: conn} do
      # Get initial count
      {:ok, initial} = MySQL.execute(conn, "SELECT COUNT(*) FROM actors", [], [])
      [[initial_count]] = initial.rows
      
      {:ok, _} = MySQL.transaction(conn, fn txn_conn ->
        {:ok, _} = MySQL.execute(txn_conn, """
          INSERT INTO actors (first_name, last_name, active) 
          VALUES ('Transaction', 'Test', true)
        """, [], [])
        :ok
      end, [])
      
      # Verify the insert was committed
      {:ok, final} = MySQL.execute(conn, "SELECT COUNT(*) FROM actors", [], [])
      [[final_count]] = final.rows
      
      assert final_count == initial_count + 1
    end
    
    test "transaction rollback", %{conn: conn} do
      # Get initial count
      {:ok, initial} = MySQL.execute(conn, "SELECT COUNT(*) FROM actors", [], [])
      [[initial_count]] = initial.rows
      
      result = MySQL.transaction(conn, fn txn_conn ->
        {:ok, _} = MySQL.execute(txn_conn, """
          INSERT INTO actors (first_name, last_name, active) 
          VALUES ('Rollback', 'Test', true)
        """, [], [])
        
        # Force rollback by raising an error
        raise "test_error"
      end, [])
      
      # Transaction should have failed
      assert {:error, _} = result
      
      # Verify the insert was rolled back
      {:ok, final} = MySQL.execute(conn, "SELECT COUNT(*) FROM actors", [], [])
      [[final_count]] = final.rows
      
      assert final_count == initial_count
    end
    
    test "savepoints", %{conn: conn} do
      # Start a manual transaction
      {:ok, _} = MySQL.execute(conn, "START TRANSACTION", [], [])
      
      # Create savepoint
      :ok = MySQL.savepoint(conn, "test_savepoint")
      
      # Make a change
      {:ok, _} = MySQL.execute(conn, """
        INSERT INTO actors (first_name, last_name, active) 
        VALUES ('Savepoint', 'Test', true)
      """, [], [])
      
      # Rollback to savepoint
      :ok = MySQL.rollback_to_savepoint(conn, "test_savepoint")
      
      # Commit transaction
      {:ok, _} = MySQL.execute(conn, "COMMIT", [], [])
      
      # Verify the insert was rolled back to savepoint
      {:ok, result} = MySQL.execute(conn, """
        SELECT COUNT(*) FROM actors WHERE first_name = 'Savepoint'
      """, [], [])
      
      [[count]] = result.rows
      assert count == 0
    end
  end
  
  describe "Error handling and edge cases" do
    test "handles invalid SQL gracefully", %{conn: conn} do
      result = MySQL.execute(conn, "INVALID SQL STATEMENT", [], [])
      assert {:error, _} = result
    end
    
    test "handles constraint violations", %{conn: conn} do
      # Try to insert duplicate primary key
      result = MySQL.execute(conn, """
        INSERT INTO actors (actor_id, first_name, last_name) 
        VALUES (1, 'Duplicate', 'Key')
      """, [], [])
      
      assert {:error, _} = result
    end
    
    test "handles NULL values correctly", %{conn: conn} do
      # Insert with NULL values
      {:ok, _} = MySQL.execute(conn, """
        INSERT INTO actors (first_name, last_name, birth_date, bio) 
        VALUES ('Null', 'Test', NULL, NULL)
      """, [], [])
      
      # Query back
      {:ok, result} = MySQL.execute(conn, """
        SELECT first_name, last_name, birth_date, bio
        FROM actors 
        WHERE first_name = 'Null'
      """, [], [])
      
      assert result.num_rows == 1
      [[first_name, last_name, birth_date, bio]] = result.rows
      assert first_name == "Null"
      assert last_name == "Test"
      assert birth_date == nil
      assert bio == nil
    end
  end
end