defmodule Selecto.DB.MySQLTest do
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
    # Check if MySQL is available for testing
    case MySQL.connect(@mysql_config) do
      {:ok, conn} ->
        MySQL.disconnect(conn)
        :ok
      {:error, reason} ->
        IO.puts("MySQL not available for testing: #{inspect(reason)}. All tests will be skipped.")
        :ok
    end
  end
  
  setup do
    # Try to connect before each test
    case MySQL.connect(@mysql_config) do
      {:ok, _conn} ->
        :ok
      {:error, _} ->
        {:skip, "MySQL not available"}
    end
  end
  
  describe "connection management" do
    @tag :mysql_required
    test "connect/1 establishes MySQL connection" do
      assert {:ok, conn} = MySQL.connect(@mysql_config)
      assert is_pid(conn)
      
      MySQL.disconnect(conn)
    end
    
    test "connect/1 with invalid credentials returns error" do
      invalid_config = Keyword.put(@mysql_config, :password, "wrong_password")
      
      assert {:error, _} = MySQL.connect(invalid_config)
    end
    
    test "disconnect/1 closes the connection" do
      {:ok, conn} = MySQL.connect(@mysql_config)
      assert :ok = MySQL.disconnect(conn)
    end
    
    test "checkout/1 returns connection for pooling" do
      {:ok, conn} = MySQL.connect(@mysql_config)
      assert {:ok, pool_conn} = MySQL.checkout(conn)
      assert is_pid(pool_conn)
      MySQL.disconnect(conn)
    end
    
    test "checkin/2 returns connection to pool" do
      {:ok, conn} = MySQL.connect(@mysql_config)
      {:ok, pool_conn} = MySQL.checkout(conn)
      assert :ok = MySQL.checkin(conn, pool_conn)
      MySQL.disconnect(conn)
    end
  end
  
  describe "query execution" do
    setup do
      {:ok, conn} = MySQL.connect(@mysql_config)
      
      # Create test table
      MySQL.execute(conn, """
        CREATE TEMPORARY TABLE test_users (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          age INT,
          email VARCHAR(255) UNIQUE,
          active BOOLEAN DEFAULT TRUE,
          score DECIMAL(5,2),
          metadata JSON,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      """, [], [])
      
      # Insert test data
      MySQL.execute(conn, """
        INSERT INTO test_users (name, age, email, score, metadata) VALUES
        ('Alice Johnson', 30, 'alice@example.com', 85.50, '{"role": "admin", "tags": ["vip"]}'),
        ('Bob Smith', 25, 'bob@example.com', 72.25, '{"role": "user", "preferences": {"theme": "dark"}}'),
        ('Carol Davis', 35, 'carol@example.com', 91.75, '{"role": "moderator", "verified": true}')
      """, [], [])
      
      on_exit(fn -> MySQL.disconnect(conn) end)
      
      {:ok, conn: conn}
    end
    
    test "execute/4 runs SELECT queries", %{conn: conn} do
      assert {:ok, result} = MySQL.execute(conn, "SELECT * FROM test_users ORDER BY id", [], [])
      
      assert length(result.columns) == 8
      assert result.num_rows == 3
      assert length(result.rows) == 3
      
      # Verify column names
      assert "id" in result.columns
      assert "name" in result.columns
      assert "email" in result.columns
    end
    
    test "execute/4 runs parameterized queries", %{conn: conn} do
      assert {:ok, result} = MySQL.execute(
        conn,
        "SELECT name, age FROM test_users WHERE age > ? ORDER BY age",
        [25],
        []
      )
      
      assert result.num_rows == 2
      assert result.columns == ["name", "age"]
      
      # Should return Alice (30) and Carol (35)
      names = Enum.map(result.rows, fn [name, _age] -> name end)
      assert "Alice Johnson" in names
      assert "Carol Davis" in names
    end
    
    test "execute/4 handles JSON data", %{conn: conn} do
      assert {:ok, result} = MySQL.execute(
        conn,
        "SELECT name, JSON_EXTRACT(metadata, '$.role') as role FROM test_users ORDER BY id",
        [],
        []
      )
      
      assert result.num_rows == 3
      assert result.columns == ["name", "role"]
      
      roles = Enum.map(result.rows, fn [_name, role] -> role end)
      assert "admin" in roles
      assert "user" in roles
      assert "moderator" in roles
    end
    
    test "prepare/3 creates prepared statements", %{conn: conn} do
      assert {:ok, prepared} = MySQL.prepare(
        conn,
        "get_user_by_age",
        "SELECT name, age FROM test_users WHERE age = ? ORDER BY name"
      )
      
      assert prepared != nil
    end
    
    test "execute_prepared/4 executes prepared statements", %{conn: conn} do
      {:ok, prepared} = MySQL.prepare(
        conn,
        "get_users_over_age",
        "SELECT name, age FROM test_users WHERE age > ? ORDER BY age DESC"
      )
      
      # Test with age > 25
      {:ok, result1} = MySQL.execute_prepared(conn, prepared, [25], [])
      assert result1.num_rows == 2
      assert result1.columns == ["name", "age"]
      
      # Test with age > 30
      {:ok, result2} = MySQL.execute_prepared(conn, prepared, [30], [])
      assert result2.num_rows == 1
      assert result2.columns == ["name", "age"]
      
      [[name, age]] = result2.rows
      assert name == "Carol Davis"
      assert age == 35
    end
    
    test "execute/4 handles errors gracefully", %{conn: conn} do
      # Invalid SQL
      assert {:error, _} = MySQL.execute(conn, "INVALID SQL STATEMENT", [], [])
      
      # Table doesn't exist
      assert {:error, _} = MySQL.execute(conn, "SELECT * FROM nonexistent_table", [], [])
    end
  end
  
  describe "transaction management" do
    setup do
      {:ok, conn} = MySQL.connect(@mysql_config)
      
      MySQL.execute(conn, """
        CREATE TEMPORARY TABLE test_transactions (
          id INT AUTO_INCREMENT PRIMARY KEY,
          value VARCHAR(50)
        )
      """, [], [])
      
      on_exit(fn -> MySQL.disconnect(conn) end)
      
      {:ok, conn: conn}
    end
    
    test "transaction/3 commits successful transactions", %{conn: conn} do
      {:ok, result} = MySQL.transaction(conn, fn txn_conn ->
        MySQL.execute(txn_conn, "INSERT INTO test_transactions (value) VALUES ('test1')", [], [])
        MySQL.execute(txn_conn, "INSERT INTO test_transactions (value) VALUES ('test2')", [], [])
        :success
      end, [])
      
      assert result == :success
      
      # Verify data was committed
      {:ok, query_result} = MySQL.execute(conn, "SELECT COUNT(*) FROM test_transactions", [], [])
      [[count]] = query_result.rows
      assert count == 2
    end
    
    test "transaction/3 rolls back on error", %{conn: conn} do
      {:error, :test_error} = MySQL.transaction(conn, fn txn_conn ->
        MySQL.execute(txn_conn, "INSERT INTO test_transactions (value) VALUES ('rollback_test')", [], [])
        {:error, :test_error}
      end, [])
      
      # Verify data was rolled back
      {:ok, query_result} = MySQL.execute(conn, "SELECT COUNT(*) FROM test_transactions", [], [])
      [[count]] = query_result.rows
      assert count == 0
    end
    
    test "begin/2, commit/1, rollback/1 manual transaction control", %{conn: conn} do
      # Test commit
      {:ok, txn_conn} = MySQL.begin(conn, [])
      MySQL.execute(txn_conn, "INSERT INTO test_transactions (value) VALUES ('manual_commit')", [], [])
      assert :ok = MySQL.commit(txn_conn)
      
      {:ok, result} = MySQL.execute(conn, "SELECT COUNT(*) FROM test_transactions", [], [])
      [[count]] = result.rows
      assert count == 1
      
      # Test rollback
      {:ok, txn_conn} = MySQL.begin(conn, [])
      MySQL.execute(txn_conn, "INSERT INTO test_transactions (value) VALUES ('manual_rollback')", [], [])
      assert :ok = MySQL.rollback(txn_conn)
      
      {:ok, result} = MySQL.execute(conn, "SELECT COUNT(*) FROM test_transactions", [], [])
      [[count]] = result.rows
      assert count == 1  # Still only 1 from the commit test
    end
    
    test "savepoint/2 and rollback_to_savepoint/2", %{conn: conn} do
      {:ok, txn_conn} = MySQL.begin(conn, [])
      
      # Insert first record
      MySQL.execute(txn_conn, "INSERT INTO test_transactions (value) VALUES ('before_savepoint')", [], [])
      
      # Create savepoint
      assert :ok = MySQL.savepoint(txn_conn, "sp1")
      
      # Insert second record
      MySQL.execute(txn_conn, "INSERT INTO test_transactions (value) VALUES ('after_savepoint')", [], [])
      
      # Rollback to savepoint
      assert :ok = MySQL.rollback_to_savepoint(txn_conn, "sp1")
      
      # Commit transaction
      assert :ok = MySQL.commit(txn_conn)
      
      # Verify only first record exists
      {:ok, result} = MySQL.execute(conn, "SELECT value FROM test_transactions ORDER BY id", [], [])
      assert result.rows == [["before_savepoint"]]
    end
  end
  
  describe "SQL dialect features" do
    test "quote_identifier/1 properly quotes identifiers" do
      assert MySQL.quote_identifier("table") == "`table`"
      assert MySQL.quote_identifier("my table") == "`my table`"
      assert MySQL.quote_identifier("table`with`backticks") == "`table``with``backticks`"
    end
    
    test "quote_string/1 properly quotes strings" do
      assert MySQL.quote_string("hello") == "'hello'"
      assert MySQL.quote_string("it's") == "'it''s'"
      assert MySQL.quote_string("'quoted'") == "'''quoted'''"
      assert MySQL.quote_string("back\\slash") == "'back\\\\slash'"
    end
    
    test "parameter_placeholder/1 returns MySQL-style placeholders" do
      assert MySQL.parameter_placeholder(1) == "?"
      assert MySQL.parameter_placeholder(2) == "?"  
      assert MySQL.parameter_placeholder(10) == "?"
    end
    
    test "limit_syntax/0 returns MySQL's limit syntax" do
      assert MySQL.limit_syntax() == :limit_offset
    end
    
    test "boolean_literal/1 converts booleans to MySQL format" do
      assert MySQL.boolean_literal(true) == "1"
      assert MySQL.boolean_literal(false) == "0"
    end
  end
  
  describe "feature capabilities" do
    test "supports?/1 returns correct feature support for MySQL 8.0+" do
      # Core SQL features (supported)
      assert MySQL.supports?(:select) == true
      assert MySQL.supports?(:insert) == true
      assert MySQL.supports?(:update) == true
      assert MySQL.supports?(:delete) == true
      assert MySQL.supports?(:joins) == true
      assert MySQL.supports?(:inner_join) == true
      assert MySQL.supports?(:left_join) == true
      assert MySQL.supports?(:right_join) == true
      assert MySQL.supports?(:cross_join) == true
      
      # Advanced features (MySQL 8.0+)
      assert MySQL.supports?(:cte) == true
      assert MySQL.supports?(:recursive_cte) == true
      assert MySQL.supports?(:window_functions) == true
      assert MySQL.supports?(:json) == true
      assert MySQL.supports?(:returning) == false  # MySQL doesn't support RETURNING
      
      # Full-text search
      assert MySQL.supports?(:fulltext_search) == true
      
      # Transaction features
      assert MySQL.supports?(:savepoints) == true
      assert MySQL.supports?(:two_phase_commit) == true
      
      # Limitations
      assert MySQL.supports?(:full_outer_join) == false
      assert MySQL.supports?(:arrays) == false  # Use JSON arrays instead
      assert MySQL.supports?(:lateral_joins) == false  # Limited support in 8.0.14+
      assert MySQL.supports?(:materialized_views) == false
    end
    
    test "capabilities/0 returns full capability map" do
      caps = MySQL.capabilities()
      
      # Check core capabilities
      assert caps.select == true
      assert caps.json == true
      assert caps.cte == true
      assert caps.window_functions == true
      assert caps.fulltext_search == true
      
      # Check limitations
      assert caps.full_outer_join == false
      assert caps.arrays == false
      assert caps.returning == false
      
      # Check metadata
      assert is_binary(caps.version)
      assert caps.dialect == "mysql"
      assert is_integer(caps.max_identifier_length)
    end
    
    test "version/0 returns MySQL version" do
      version = MySQL.version()
      assert is_binary(version)
      # Should be something like "8.0.35"
      assert version =~ ~r/^\d+\.\d+/
    end
  end
  
  describe "type system" do
    setup do
      {:ok, conn} = MySQL.connect(@mysql_config)
      on_exit(fn -> MySQL.disconnect(conn) end)
      {:ok, conn: conn}
    end
    
    test "encode_type/2 converts Elixir types to MySQL format" do
      assert MySQL.encode_type(true, :boolean) == true
      assert MySQL.encode_type(false, :boolean) == false
      
      dt = ~U[2024-01-15 10:30:00Z]
      encoded_dt = MySQL.encode_type(dt, :datetime)
      assert is_binary(encoded_dt) or is_struct(encoded_dt, DateTime)
      
      d = ~D[2024-01-15]
      encoded_d = MySQL.encode_type(d, :date)
      assert is_binary(encoded_d) or is_struct(encoded_d, Date)
      
      t = ~T[10:30:00]
      encoded_t = MySQL.encode_type(t, :time)
      assert is_binary(encoded_t) or is_struct(encoded_t, Time)
      
      map = %{key: "value"}
      encoded_json = MySQL.encode_type(map, :json)
      assert is_binary(encoded_json)
      assert encoded_json == Jason.encode!(map)
      
      assert MySQL.encode_type("string", :string) == "string"
      assert MySQL.encode_type(42, :integer) == 42
      assert MySQL.encode_type(3.14, :decimal) == 3.14
    end
    
    test "decode_type/2 converts MySQL values to Elixir types", %{conn: conn} do
      # Test with actual data from database
      {:ok, _} = MySQL.execute(conn, """
        CREATE TEMPORARY TABLE type_test (
          id INT PRIMARY KEY,
          bool_val BOOLEAN,
          date_val DATE,
          datetime_val DATETIME,
          time_val TIME,
          json_val JSON,
          decimal_val DECIMAL(10,2)
        )
      """, [], [])
      
      {:ok, _} = MySQL.execute(conn, """
        INSERT INTO type_test VALUES (
          1, TRUE, '2024-01-15', '2024-01-15 10:30:00', '10:30:00', 
          '{"test": true}', 123.45
        )
      """, [], [])
      
      {:ok, result} = MySQL.execute(conn, "SELECT * FROM type_test", [], [])
      
      [[id, bool_val, date_val, datetime_val, time_val, json_val, decimal_val]] = result.rows
      
      # Basic assertions about returned types
      assert is_integer(id)
      assert is_boolean(bool_val) or bool_val in [0, 1]
      assert is_binary(json_val) or is_map(json_val)
      assert is_number(decimal_val)
    end
    
    test "type_name/1 returns MySQL type names" do
      assert MySQL.type_name(:id) == "INT AUTO_INCREMENT"
      assert MySQL.type_name(:binary_id) == "CHAR(36)"
      assert MySQL.type_name(:integer) == "INT"
      assert MySQL.type_name(:bigint) == "BIGINT"
      assert MySQL.type_name(:float) == "DOUBLE"
      assert MySQL.type_name(:decimal) == "DECIMAL(10,2)"
      assert MySQL.type_name(:boolean) == "TINYINT(1)"
      assert MySQL.type_name(:string) == "VARCHAR(255)"
      assert MySQL.type_name(:text) == "TEXT"
      assert MySQL.type_name(:binary) == "BLOB"
      assert MySQL.type_name(:date) == "DATE"
      assert MySQL.type_name(:time) == "TIME"
      assert MySQL.type_name(:datetime) == "DATETIME"
      assert MySQL.type_name(:utc_datetime) == "TIMESTAMP"
      assert MySQL.type_name(:json) == "JSON"
      assert MySQL.type_name(:uuid) == "CHAR(36)"
      assert MySQL.type_name(:unknown) == "VARCHAR(255)"
    end
  end
  
  describe "introspection" do
    setup do
      {:ok, conn} = MySQL.connect(@mysql_config)
      
      # Create test tables
      MySQL.execute(conn, """
        CREATE TEMPORARY TABLE introspect_users (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          email VARCHAR(255) UNIQUE,
          active BOOLEAN DEFAULT TRUE
        )
      """, [], [])
      
      MySQL.execute(conn, """
        CREATE TEMPORARY TABLE introspect_posts (
          id INT AUTO_INCREMENT PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          content TEXT,
          user_id INT,
          FOREIGN KEY (user_id) REFERENCES introspect_users(id)
        )
      """, [], [])
      
      on_exit(fn -> MySQL.disconnect(conn) end)
      
      {:ok, conn: conn}
    end
    
    test "list_tables/2 returns user tables", %{conn: conn} do
      {:ok, tables} = MySQL.list_tables(conn, [])
      
      # Should include our test tables (temporary tables might not be listed)
      assert is_list(tables)
      # Note: Temporary tables may not appear in INFORMATION_SCHEMA
    end
    
    test "table_exists?/3 checks table existence", %{conn: conn} do
      # Test with a known system table
      assert MySQL.table_exists?(conn, "INFORMATION_SCHEMA.TABLES", []) == true
      assert MySQL.table_exists?(conn, "nonexistent_table_12345", []) == false
    end
    
    test "describe_table/3 returns table structure", %{conn: conn} do
      # Use a system table that definitely exists
      {:ok, info} = MySQL.describe_table(conn, "INFORMATION_SCHEMA.TABLES", [])
      
      assert is_map(info)
      assert info.table == "TABLES"
      assert is_list(info.columns)
      assert length(info.columns) > 0
      
      # Check column structure
      column = List.first(info.columns)
      assert is_map(column)
      assert Map.has_key?(column, :name)
      assert Map.has_key?(column, :type)
    end
  end
  
  describe "performance and optimization" do
    setup do
      {:ok, conn} = MySQL.connect(@mysql_config)
      
      MySQL.execute(conn, """
        CREATE TEMPORARY TABLE perf_test (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(100),
          category VARCHAR(50),
          score INT,
          INDEX idx_category (category),
          INDEX idx_score (score)
        )
      """, [], [])
      
      # Insert test data
      for i <- 1..20 do
        MySQL.execute(conn, 
          "INSERT INTO perf_test (name, category, score) VALUES (?, ?, ?)",
          ["Item #{i}", "Category #{rem(i, 5) + 1}", i * 10],
          []
        )
      end
      
      on_exit(fn -> MySQL.disconnect(conn) end)
      
      {:ok, conn: conn}
    end
    
    test "explain/3 returns query execution plan", %{conn: conn} do
      {:ok, plan} = MySQL.explain(conn, """
        SELECT * FROM perf_test 
        WHERE category = 'Category 1' AND score > 50
        ORDER BY score DESC
      """, [])
      
      assert is_map(plan) or is_list(plan)
      # EXPLAIN returns execution plan details
    end
    
    test "analyze/3 updates table statistics", %{conn: conn} do
      # MySQL ANALYZE TABLE updates statistics
      assert :ok = MySQL.analyze(conn, "perf_test", [])
    end
  end
end