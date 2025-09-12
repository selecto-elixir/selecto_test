defmodule MySQLLocalSimpleTest do
  use ExUnit.Case, async: false
  
  # Skip MySQL-dependent tests by default
  @moduletag :mysql_integration
  
  alias Selecto.DB.MySQL
  
  @mysql_config [
    hostname: "localhost",
    port: 3306,
    username: "selecto_user",
    password: "selecto_password",
    database: "selecto_test"
  ]
  
  setup_all do
    # Skip setup if MySQL tests are not enabled
    unless System.get_env("TEST_MYSQL") do
      :ok
    else
      # Use local MySQL installation
      IO.puts("Connecting to local MySQL installation...")
      
      # Create test database and schema
      setup_mysql_test_db()
      
      on_exit(fn ->
        cleanup_mysql_test_data()
      end)
      
      :ok
    end
  end
  
  defp setup_mysql_test_db do
    case MySQL.connect(@mysql_config) do
      {:ok, conn} ->
        IO.puts("Connected to MySQL, creating schema...")
        result = create_simple_schema(conn)
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
  
  defp create_simple_schema(conn) do
    try do
      # Drop table if it exists and recreate
      case MySQL.execute(conn, "DROP TABLE IF EXISTS actors", [], []) do
        {:ok, _} -> IO.puts("Dropped existing actors table")
        {:error, reason} -> IO.puts("Warning: Could not drop actors table: #{inspect(reason)}")
      end
      
      # Create simple actors table
      case MySQL.execute(conn, """
        CREATE TABLE IF NOT EXISTS actors (
          actor_id INT AUTO_INCREMENT PRIMARY KEY,
          first_name VARCHAR(45) NOT NULL,
          last_name VARCHAR(45) NOT NULL,
          active BOOLEAN DEFAULT TRUE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      """, [], []) do
        {:ok, _} -> 
          IO.puts("Actors table created successfully")
        {:error, reason} -> 
          IO.puts("Failed to create actors table: #{inspect(reason)}")
          throw({:error, reason})
      end
      
      # Clear any existing data
      case MySQL.execute(conn, "TRUNCATE TABLE actors", [], []) do
        {:ok, _} -> IO.puts("Cleared existing data from actors table")
        {:error, reason} -> IO.puts("Warning: Could not clear actors table: #{inspect(reason)}")
      end
    
      # Insert test data
      case MySQL.execute(conn, """
        INSERT INTO actors (first_name, last_name, active) VALUES
        ('John', 'Doe', true),
        ('Jane', 'Smith', true),
        ('Bob', 'Wilson', false)
      """, [], []) do
        {:ok, _} -> 
          IO.puts("Test data inserted successfully")
        {:error, reason} -> 
          IO.puts("Failed to insert test data: #{inspect(reason)}")
          throw({:error, reason})
      end
      
      # Verify data exists
      case MySQL.execute(conn, "SELECT COUNT(*) FROM actors", [], []) do
        {:ok, result} -> 
          [[count]] = result.rows
          IO.puts("Verified #{count} actors in database")
          :ok
        {:error, reason} -> 
          IO.puts("Failed to verify data: #{inspect(reason)}")
          throw({:error, reason})
      end
    catch
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp cleanup_mysql_test_data do
    case MySQL.connect(@mysql_config) do
      {:ok, conn} ->
        MySQL.execute(conn, "DROP TABLE IF EXISTS actors", [], [])
        try do
          MySQL.disconnect(conn)
        rescue
          _ -> :ok
        end
        IO.puts("MySQL test data cleaned up")
      {:error, reason} ->
        IO.puts("Could not connect to MySQL for cleanup: #{inspect(reason)}")
        :ok
    end
  end
  
  test "basic MySQL query works" do
    case MySQL.connect(@mysql_config) do
      {:ok, conn} ->
        case MySQL.execute(conn, "SELECT actor_id, first_name, last_name FROM actors WHERE active = ?", [true], []) do
          {:ok, result} ->
            IO.puts("Query successful! Found #{result.num_rows} active actors")
            assert result.num_rows >= 2
            assert "actor_id" in result.columns
            assert "first_name" in result.columns
            assert "last_name" in result.columns
            
            # Verify we got actual data
            assert length(result.rows) >= 2
            
          {:error, reason} ->
            IO.puts("Query failed: #{inspect(reason)}")
            flunk("Basic query failed")
        end
        
        MySQL.disconnect(conn)
      {:error, _reason} ->
        # Skip test if MySQL is not available
        :ok
    end
  end
end