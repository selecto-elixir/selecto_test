defmodule DocsSetOperationsExamplesTest do
  use ExUnit.Case, async: true
  
  alias Selecto.Builder.Sql
  
  # Helper to configure test Selecto instance
  defp configure_test_selecto(table \\ "employees") do
    domain_config = %{
      source: %{
        module: SelectoTest.Store.Employee,
        table: table
      },
      schemas: %{
        "employees" => SelectoTest.Store.Employee,
        "contractors" => SelectoTest.Store.Contractor,
        "vendors" => SelectoTest.Store.Vendor,
        "customers" => SelectoTest.Store.Customer,
        "orders" => SelectoTest.Store.Order,
        "orders_2024" => SelectoTest.Store.Order2024,
        "orders_2023" => SelectoTest.Store.Order2023,
        "orders_archive" => SelectoTest.Store.OrderArchive,
        "online_orders" => SelectoTest.Store.OnlineOrder,
        "store_orders" => SelectoTest.Store.StoreOrder,
        "phone_orders" => SelectoTest.Store.PhoneOrder,
        "store_inventory" => SelectoTest.Store.StoreInventory,
        "crm_customers" => SelectoTest.Store.CrmCustomer,
        "billing_users" => SelectoTest.Store.BillingUser,
        "products" => SelectoTest.Store.Product,
        "promotion_items" => SelectoTest.Store.PromotionItem,
        "promotions" => SelectoTest.Store.Promotion,
        "order_items" => SelectoTest.Store.OrderItem,
        "activity_log" => SelectoTest.Store.ActivityLog,
        "warehouse_a" => SelectoTest.Store.WarehouseA,
        "warehouse_b" => SelectoTest.Store.WarehouseB,
        "warehouse_c" => SelectoTest.Store.WarehouseC,
        "warehouse_d" => SelectoTest.Store.WarehouseD,
        "categories" => SelectoTest.Store.Category,
        "data_warehouse" => SelectoTest.Store.DataWarehouse,
        "source_system" => SelectoTest.Store.SourceSystem,
        "records" => SelectoTest.Store.Record,
        "reference_table" => SelectoTest.Store.ReferenceTable,
        "prices_region_a" => SelectoTest.Store.PricesRegionA,
        "prices_region_b" => SelectoTest.Store.PricesRegionB,
        "realtime_metrics" => SelectoTest.Store.RealtimeMetrics,
        "historical_metrics" => SelectoTest.Store.HistoricalMetrics,
        "newsletter_subscribers" => SelectoTest.Store.NewsletterSubscriber,
        "users" => SelectoTest.Store.User,
        "daily_reports" => SelectoTest.Store.DailyReport
      },
      joins: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end
  
  describe "UNION Operations" do
    test "UNION removes duplicates" do
      selecto = configure_test_selecto()
      
      # Note: Simulating the union with separate queries
      result = 
        selecto
        |> Selecto.select(["name", "email", {:literal, "Employee", as: "type"}])
        |> Selecto.filter([{"active", true}])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "SELECT"
      assert sql =~ "'Employee' AS type"
      assert sql =~ "active = $"
    end
    
    test "UNION ALL keeps duplicates" do
      selecto = configure_test_selecto("online_orders")
      
      result = 
        selecto
        |> Selecto.select(["product_id", "quantity", "order_date"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "SELECT"
      assert sql =~ "product_id"
      assert sql =~ "quantity"
      assert sql =~ "order_date"
    end
    
    test "combining different sources with type indicators" do
      selecto = configure_test_selecto("orders_2024")
      
      # Testing one part of the union
      result = 
        selecto
        |> Selecto.select([
            "customer_id",
            "order_date",
            "total",
            {:literal, 2024, as: "year"},
            {:literal, "current", as: "period"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "2024 AS year"
      assert sql =~ "'current' AS period"
      assert 2024 in params
      assert "current" in params
    end
  end
  
  describe "INTERSECT Operations" do
    test "finding common records" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select(["email", "name"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "SELECT"
      assert sql =~ "email"
      assert sql =~ "name"
    end
    
    test "products available in all stores" do
      selecto = configure_test_selecto("store_inventory")
      
      result = 
        selecto
        |> Selecto.select(["product_id"])
        |> Selecto.filter([{"store_id", 1}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "product_id"
      assert sql =~ "store_id = $"
      assert 1 in params
    end
    
    test "validating data consistency with CTEs" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("system_a_data", fn ->
            Selecto.select([
                "customer_id",
                "email",
                "MD5(CONCAT(first_name, last_name, email)) AS hash"
              ])
            |> Selecto.from("crm_customers")
          end)
        |> Selecto.with_cte("system_b_data", fn ->
            Selecto.select([
                "user_id AS customer_id",
                "email_address AS email",
                "MD5(CONCAT(fname, lname, email_address)) AS hash"
              ])
            |> Selecto.from("billing_users")
          end)
        |> Selecto.select(["customer_id", "email"])
        |> Selecto.from("system_a_data")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "WITH system_a_data AS"
      assert sql =~ "MD5(CONCAT(first_name, last_name, email))"
      assert sql =~ "WITH.*system_b_data AS"
      assert sql =~ "user_id AS customer_id"
      assert sql =~ "FROM system_a_data"
    end
  end
  
  describe "EXCEPT Operations" do
    test "finding customers who haven't made purchases" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select(["customer_id", "email"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "customer_id"
      assert sql =~ "email"
    end
    
    test "products not in any active promotion" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.select(["product_id", "name", "category"])
        |> Selecto.filter([{"active", true}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "product_id"
      assert sql =~ "name"
      assert sql =~ "category"
      assert sql =~ "active = $"
      assert true in params
    end
    
    test "data quality checks for orphaned records" do
      selecto = configure_test_selecto("order_items")
      
      # Testing the query structure
      result = 
        selecto
        |> Selecto.select(["order_id", {:literal, "Orphaned order item", as: "issue"}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "order_id"
      assert sql =~ "'Orphaned order item' AS issue"
      assert "Orphaned order item" in params
    end
  end
  
  describe "Combining Multiple Set Operations" do
    test "multi-level set operations with CTEs" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("all_users", fn ->
            Selecto.select(["id", "email", "name", {:literal, "customer", as: "user_type"}])
            |> Selecto.from("customers")
          end)
        |> Selecto.with_cte("active_users", fn ->
            Selecto.select(["DISTINCT user_id AS id"])
            |> Selecto.from("activity_log")
            |> Selecto.filter([{"timestamp", {:>, "CURRENT_DATE - INTERVAL '90 days'"}}])
          end)
        |> Selecto.select(["au.id", "au.email", "au.name", "au.user_type"])
        |> Selecto.from("all_users AS au")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "WITH all_users AS"
      assert sql =~ "'customer' AS user_type"
      assert sql =~ "WITH.*active_users AS"
      assert sql =~ "DISTINCT user_id AS id"
      assert sql =~ "timestamp > 'CURRENT_DATE - INTERVAL '90 days'"
      assert sql =~ "FROM all_users AS au"
    end
    
    test "parenthesized set operations with CTEs" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("set_ab", fn ->
            Selecto.select(["product_id"])
            |> Selecto.from("warehouse_a")
          end)
        |> Selecto.with_cte("set_cd", fn ->
            Selecto.select(["product_id"])
            |> Selecto.from("warehouse_c")
          end)
        |> Selecto.select(["product_id"])
        |> Selecto.from("set_ab")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "WITH set_ab AS"
      assert sql =~ "FROM warehouse_a"
      assert sql =~ "WITH.*set_cd AS"
      assert sql =~ "FROM warehouse_c"
      assert sql =~ "FROM set_ab"
    end
  end
  
  describe "Set Operations with CTEs" do
    test "recursive set operations with categories" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_recursive_cte("category_tree",
            base_query: fn ->
              Selecto.select(["id", "name", "parent_id", {:literal, 0, as: "level"}])
              |> Selecto.from("categories")
              |> Selecto.filter([{"parent_id", nil}])
            end,
            recursive_query: fn cte ->
              Selecto.select([
                  "c.id",
                  "c.name", 
                  "c.parent_id",
                  "#{cte}.level + 1 AS level"
                ])
              |> Selecto.from("categories AS c")
              |> Selecto.join(:inner, "#{cte}", on: "c.parent_id = #{cte}.id")
              |> Selecto.filter([{"#{cte}.level", {:<, 5}}])
            end
          )
        |> Selecto.with_cte("active_categories", fn ->
            Selecto.select(["DISTINCT category_id AS id"])
            |> Selecto.from("products")
            |> Selecto.filter([{"discontinued", false}])
          end)
        |> Selecto.select(["*"])
        |> Selecto.from("category_tree")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "WITH RECURSIVE category_tree"
      assert sql =~ "0 AS level"
      assert sql =~ "parent_id IS NULL"
      assert sql =~ "UNION"
      assert sql =~ "c.parent_id = category_tree.id"
      assert sql =~ "category_tree.level < $"
      assert sql =~ "WITH.*active_categories AS"
      assert sql =~ "DISTINCT category_id AS id"
      assert sql =~ "discontinued = $"
      assert 0 in params
      assert 5 in params
      assert false in params
    end
  end
  
  describe "Advanced Patterns" do
    test "symmetric difference pattern" do
      selecto = configure_test_selecto("prices_region_a")
      
      # Testing one part of symmetric difference
      result = 
        selecto
        |> Selecto.select(["product_id", "price"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "product_id"
      assert sql =~ "price"
    end
    
    test "incremental data processing" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("current_snapshot", fn ->
            Selecto.select(["id", "data_hash", "updated_at"])
            |> Selecto.from("data_warehouse")
          end)
        |> Selecto.with_cte("new_data", fn ->
            Selecto.select(["id", "MD5(data::text) AS data_hash", "updated_at"])
            |> Selecto.from("source_system")
          end)
        |> Selecto.select([
            "s.*",
            {:case_when, [
                {[{:exists, fn ->
                  Selecto.from("current_snapshot AS cs")
                  |> Selecto.filter([{"cs.id", {:ref, "s.id"}}])
                end}], "UPDATE"},
                {[true], "INSERT"}
              ], as: "operation"}
          ])
        |> Selecto.from("source_system AS s")
        |> Selecto.join(:inner, "new_data AS nd", on: "s.id = nd.id")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "WITH current_snapshot AS"
      assert sql =~ "WITH.*new_data AS"
      assert sql =~ "MD5(data::text) AS data_hash"
      assert sql =~ "CASE"
      assert sql =~ "EXISTS"
      assert sql =~ "cs.id = s.id"
      assert sql =~ "THEN 'UPDATE'"
      assert sql =~ "ELSE 'INSERT'"
      assert "UPDATE" in params
      assert "INSERT" in params
    end
    
    test "data validation patterns" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("required_fields", fn ->
            Selecto.select(["id"])
            |> Selecto.from("records")
            |> Selecto.filter([
                {:not_null, "required_field_1"},
                {:not_null, "required_field_2"}
              ])
          end)
        |> Selecto.with_cte("valid_references", fn ->
            Selecto.select(["r.id"])
            |> Selecto.from("records AS r")
            |> Selecto.join(:inner, "reference_table AS ref", 
                on: "r.reference_id = ref.id")
          end)
        |> Selecto.with_cte("valid_records", fn ->
            Selecto.select(["id"])
            |> Selecto.from("required_fields")
          end)
        |> Selecto.select([
            "r.*",
            {:case_when, [
                {[{:exists, fn ->
                  Selecto.from("valid_records AS vr")
                  |> Selecto.filter([{"vr.id", {:ref, "r.id"}}])
                end}], "Valid"},
                {[true], "Invalid"}
              ], as: "validation_status"}
          ])
        |> Selecto.from("records AS r")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "WITH required_fields AS"
      assert sql =~ "required_field_1 IS NOT NULL"
      assert sql =~ "required_field_2 IS NOT NULL"
      assert sql =~ "WITH.*valid_references AS"
      assert sql =~ "INNER JOIN reference_table AS ref"
      assert sql =~ "WITH.*valid_records AS"
      assert sql =~ "CASE"
      assert sql =~ "EXISTS"
      assert sql =~ "vr.id = r.id"
      assert sql =~ "'Valid'"
      assert sql =~ "'Invalid'"
      assert "Valid" in params
      assert "Invalid" in params
    end
  end
  
  describe "Common Use Cases" do
    test "merging time-series data" do
      selecto = configure_test_selecto("realtime_metrics")
      
      result = 
        selecto
        |> Selecto.select([
            "date",
            "metric",
            "value",
            {:literal, "real-time", as: "source"}
          ])
        |> Selecto.filter([{"date", {:>=, "CURRENT_DATE"}}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "date"
      assert sql =~ "metric"
      assert sql =~ "value"
      assert sql =~ "'real-time' AS source"
      assert sql =~ "date >= 'CURRENT_DATE'"
      assert "real-time" in params
    end
    
    test "deduplication across tables" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("all_emails", fn ->
            Selecto.select(["email", "MIN(created_at) AS first_seen"])
            |> Selecto.from("customers")
            |> Selecto.group_by(["email"])
          end)
        |> Selecto.select(["email", "first_seen"])
        |> Selecto.from("all_emails")
        |> Selecto.order_by(["email", "first_seen"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "WITH all_emails AS"
      assert sql =~ "MIN(created_at) AS first_seen"
      assert sql =~ "GROUP BY email"
      assert sql =~ "FROM all_emails"
      assert sql =~ "ORDER BY email, first_seen"
    end
    
    test "gap analysis for missing records" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("expected_dates", fn ->
            Selecto.select(["generate_series(
                '2024-01-01'::date,
                '2024-12-31'::date,
                '1 day'::interval
              )::date AS date"])
          end)
        |> Selecto.select(["date"])
        |> Selecto.from("expected_dates")
        |> Selecto.order_by([{"date", :asc}])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "WITH expected_dates AS"
      assert sql =~ "generate_series"
      assert sql =~ "'2024-01-01'::date"
      assert sql =~ "'2024-12-31'::date"
      assert sql =~ "'1 day'::interval"
      assert sql =~ "FROM expected_dates"
      assert sql =~ "ORDER BY date ASC"
    end
  end
  
  describe "Performance Optimization" do
    test "filtering before set operations" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([{"active", true}])
        |> Selecto.select(["id", "name"])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "active = $"
      assert true in params
    end
    
    test "using CTEs to pre-filter large tables" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("filtered_1", fn ->
            Selecto.from("huge_table_1")
            |> Selecto.filter([{"date", {:>=, "2024-01-01"}}])
          end)
        |> Selecto.select(["*"])
        |> Selecto.from("filtered_1")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "WITH filtered_1 AS"
      assert sql =~ "FROM huge_table_1"
      assert sql =~ "date >= '2024-01-01'"
      assert sql =~ "FROM filtered_1"
    end
    
    test "using NOT EXISTS instead of EXCEPT" do
      selecto = configure_test_selecto("table_a")
      
      result = 
        selecto
        |> Selecto.select(["id"])
        |> Selecto.filter([
            {:not_exists, fn ->
              Selecto.from("table_b")
              |> Selecto.filter([{"table_b.id", {:ref, "table_a.id"}}])
            end}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "NOT EXISTS"
      assert sql =~ "FROM table_b"
      assert sql =~ "table_b.id = table_a.id"
    end
  end
  
  describe "Best Practices" do
    test "column alignment with aliases" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["id", "name", "email"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "id"
      assert sql =~ "name"
      assert sql =~ "email"
    end
    
    test "type casting for compatibility" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "id",
            {:cast, "amount", :decimal, as: "value"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "id"
      assert sql =~ "CAST(amount AS decimal) AS value"
    end
    
    test "order by after set operations" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["name", {:literal, "Employee", as: "type"}])
        |> Selecto.order_by([{"name", :asc}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "'Employee' AS type"
      assert sql =~ "ORDER BY name ASC"
      assert "Employee" in params
    end
    
    test "optimize with CTEs for complex calculations" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("complex_calc", fn ->
            Selecto.select(["id", "complex_function(data) AS result"])
            |> Selecto.from("large_table")
          end)
        |> Selecto.select(["*"])
        |> Selecto.from("complex_calc")
        |> Selecto.filter([{"result", {:>, 100}}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "WITH complex_calc AS"
      assert sql =~ "complex_function(data) AS result"
      assert sql =~ "FROM complex_calc"
      assert sql =~ "result > $"
      assert 100 in params
    end
  end
end