defmodule SelectoBasicIntegrationTest do
  use ExUnit.Case, async: false
  
  # Basic integration tests for Selecto with Pagila database
  # Tests core functionality with corrected API format

  setup_all do
    # Set up database connection
    repo_config = SelectoTest.Repo.config()
    postgrex_opts = [
      username: repo_config[:username],
      password: repo_config[:password],
      hostname: repo_config[:hostname], 
      database: repo_config[:database],
      port: repo_config[:port] || 5432
    ]
    
    {:ok, db_conn} = Postgrex.start_link(postgrex_opts)
    
    # Define actor domain for testing
    domain = %{
      source: %{
        source_table: "actor",
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
      name: "Actor",
      joins: %{},
      schemas: %{}
    }
    
    selecto = Selecto.configure(domain, db_conn)
    
    {:ok, selecto: selecto, db_conn: db_conn}
  end

  describe "Basic Functionality" do
    test "select single field with filter", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"actor_id", 1})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name"]
      assert length(rows) == 1
      assert hd(rows) == ["PENELOPE"]
    end

    test "select multiple fields with filter", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name", "last_name"])
      |> Selecto.filter({"actor_id", 1})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name", "last_name"]
      assert length(rows) == 1
      assert hd(rows) == ["PENELOPE", "GUINESS"]
    end

    test "select without filter returns all rows", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["actor_id"]
      assert length(rows) == 200  # Total actors in Pagila DB
    end

    test "filter by exact match", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name", "last_name"])
      |> Selecto.filter({"first_name", "JOHNNY"})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0
      # All returned rows should have first_name = "JOHNNY"
      Enum.each(rows, fn [first_name, _] -> 
        assert first_name == "JOHNNY"
      end)
    end

    test "filter by range", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {">", 195}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 5  # actors 196-200
      Enum.each(rows, fn [actor_id] -> 
        assert actor_id > 195
      end)
    end

    test "filter by IN clause", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", [1, 2, 3]})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 3
      ids = Enum.map(rows, fn [id] -> id end)
      assert Enum.sort(ids) == [1, 2, 3]
    end
  end

  describe "Ordering" do
    test "order by single field ascending", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"actor_id", [3, 1, 2]})  # Intentionally out of order
      |> Selecto.order_by("first_name")
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      names = Enum.map(rows, fn [name] -> name end)
      assert names == Enum.sort(names)
    end

    test "order by single field descending", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", [1, 2, 3]})
      |> Selecto.order_by({:desc, "actor_id"})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      ids = Enum.map(rows, fn [id] -> id end)
      assert ids == [3, 2, 1]
    end
  end

  describe "Aggregation" do
    test "count all records", %{selecto: selecto} do
      result = selecto
      |> Selecto.select([{:count, "*"}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["count"]
      assert rows == [[200]]
    end

    test "count with filter", %{selecto: selecto} do
      result = selecto
      |> Selecto.select([{:count, "*"}])
      |> Selecto.filter({"actor_id", {">", 190}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert rows == [[10]]  # actors 191-200
    end

    test "min and max aggregates", %{selecto: selecto} do
      result = selecto
      |> Selecto.select([{:min, "actor_id"}, {:max, "actor_id"}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["min", "max"]
      assert rows == [[1, 200]]
    end
  end

  describe "SQL Generation" do
    test "to_sql generates correct query", %{selecto: selecto} do
      {sql, params} = selecto
      |> Selecto.select(["first_name", "last_name"])
      |> Selecto.filter({"actor_id", 1})
      |> Selecto.to_sql()
      
      assert is_binary(sql)
      assert String.contains?(sql, "select")
      assert String.contains?(sql, "first_name")
      assert String.contains?(sql, "last_name") 
      assert String.contains?(sql, "actor")
      assert String.contains?(sql, "where")
      assert params == [1]
    end

    test "to_sql with no filter", %{selecto: selecto} do
      {sql, params} = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.to_sql()
      
      assert is_binary(sql)
      assert String.contains?(sql, "select")
      assert String.contains?(sql, "first_name")
      refute String.contains?(sql, "where")  # Should not have WHERE clause
      assert params == []
    end
  end

  describe "Error Handling" do
    test "invalid field name returns error", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["nonexistent_field"])
      |> Selecto.execute()
      
      # Should return an error, not crash
      assert {:error, _error} = result
    end
  end
end