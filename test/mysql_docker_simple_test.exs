defmodule MySQLDockerSimpleTest do
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
        MySQL.disconnect(conn)
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
        IO.puts("Connected to MySQL, creating schema...")
        result = create_simple_schema(conn)
        MySQL.disconnect(conn)
        result
      {:error, reason} ->
        IO.puts("Failed to connect to MySQL: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp create_simple_schema(conn) do
    try do
      # Drop tables if they exist
      MySQL.execute(conn, "DROP TABLE IF EXISTS actors", [], [])
      
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
    System.cmd("docker", ["stop", "selecto_mysql_test"], stderr_to_stdout: true)
    System.cmd("docker", ["rm", "selecto_mysql_test"], stderr_to_stdout: true)
    IO.puts("MySQL Docker container cleaned up")
  end
  
  test "basic MySQL query works" do
    {:ok, conn} = MySQL.connect(@mysql_config)
    
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
  end
end