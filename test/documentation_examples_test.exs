defmodule DocumentationExamplesTest do
  use ExUnit.Case, async: true
  
  # Skip all tests in this module since they use aspirational API
  @moduletag :skip
  @moduledoc """
  These tests are for documentation examples that use aspirational/planned API.
  The actual Selecto API differs from what's shown in documentation.
  These tests are skipped until either:
  1. The Selecto API is updated to match documentation, or
  2. The documentation is updated to match the actual API
  
  Key differences:
  - Selecto.from/1 and Selecto.join/4 don't exist as standalone functions
  - Window functions use window_function/3 then select, not inline in select
  - Set operations take two complete queries, not chained methods
  - Many other API differences
  """
  
  # Helper function to configure test Selecto instance
  defp configure_test_selecto(domain \\ :film) do
    # Mock domain configuration map for testing
    domain_config = %{
      source: %{
        module: SelectoTest.Store.Film,
        table: "film"
      },
      schemas: %{
        "film" => SelectoTest.Store.Film,
        "category" => SelectoTest.Store.Category,
        "customer" => SelectoTest.Store.Customer,
        "order" => SelectoTest.Store.Order,
        "product" => SelectoTest.Store.Product,
        "employee" => SelectoTest.Store.Employee
      },
      joins: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end

  describe "README.md Examples" do
    test "Array Operations - array_agg with order_by" do
      selecto = configure_test_selecto(:category)
      
      result = 
        selecto
        |> Selecto.select([
            "category.name",
            {:array_agg, "film.title", order_by: [{"release_year", :desc}], as: "films"}
          ])
        |> Selecto.group_by(["category.name"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "ORDER BY"
      assert sql =~ "release_year"
      assert sql =~ "DESC"
      assert sql =~ "GROUP BY"
    end

    test "JSON Operations - json_get_text and jsonb_path_query" do
      selecto = configure_test_selecto(:product)
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:json_get_text, "metadata", "category", as: "category"},
            {:jsonb_path_query, "specs", "$.features[*].name", as: "features"}
          ])
        |> Selecto.filter([{:jsonb_contains, "metadata", %{"active" => true}}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "metadata->>'category'"
      assert sql =~ "jsonb_path_query"
      assert sql =~ "$.features[*].name"
      assert sql =~ "@>"
      assert %{"active" => true} in params
    end

    test "Recursive CTE - organizational hierarchy" do
      selecto = configure_test_selecto(:employee)
      
      result = 
        selecto
        |> Selecto.with_recursive_cte("org_hierarchy",
            base_query: fn ->
              Selecto.filter([{"manager_id", nil}])
            end,
            recursive_query: fn cte ->
              Selecto.join(:inner, cte, on: "employee.manager_id = #{cte}.employee_id")
            end
          )
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH RECURSIVE org_hierarchy"
      assert sql =~ "manager_id IS NULL"
      assert sql =~ "UNION"
    end

    test "LATERAL Join - recent orders per customer" do
      selecto = configure_test_selecto(:customer)
      
      result = 
        selecto
        |> Selecto.lateral_join(:left,
            fn base ->
              Selecto.select(["order_id", "total"])
              |> Selecto.filter([{"customer_id", {:ref, "customer.id"}}])
              |> Selecto.order_by([{"order_date", :desc}])
              |> Selecto.limit(5)
            end,
            as: "recent_orders"
          )
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN LATERAL"
      assert sql =~ "customer_id = customer.id"
      assert sql =~ "ORDER BY order_date DESC"
      assert sql =~ "LIMIT 5"
    end

    test "CASE Expression - customer tier classification" do
      selecto = configure_test_selecto(:customer)
      
      result = 
        selecto
        |> Selecto.select([
            "customer.name",
            {:case_when, [
                {[{"total_spent", {:>=, 10000}}], "Platinum"},
                {[{"total_spent", {:>=, 5000}}], "Gold"},
                {[{"total_spent", {:>=, 1000}}], "Silver"}
              ],
              else: "Bronze",
              as: "tier"
            }
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "WHEN total_spent >= $"
      assert sql =~ "THEN 'Platinum'"
      assert sql =~ "THEN 'Gold'"
      assert sql =~ "THEN 'Silver'"
      assert sql =~ "ELSE 'Bronze'"
      assert 10000 in params
      assert 5000 in params
      assert 1000 in params
    end
  end

  describe "Quick Start Example from README" do
    test "Combined advanced features example" do
      selecto = configure_test_selecto()
      
      # This tests the Quick Start example from the README
      result = 
        selecto
        |> Selecto.with_cte("filtered_data", fn -> 
            Selecto.filter([{"active", true}])
          end)
        |> Selecto.select([
            {:json_get, "data", "field", as: "extracted"},
            {:array_agg, "tags", as: "all_tags"},
            {:case_when, [
              {[{"status", "premium"}], "VIP"},
              {[{"status", "standard"}], "Regular"}
            ], as: "category"}
          ])
        |> Selecto.lateral_join(:left, fn base -> 
            Selecto.select(["related_id", "score"])
            |> Selecto.filter([{"main_id", {:ref, "filtered_data.id"}}])
            |> Selecto.limit(10)
          end, as: "related")
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      # Verify all components are present
      assert sql =~ "WITH filtered_data AS"
      assert sql =~ "data->'field'"
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "CASE WHEN"
      assert sql =~ "LEFT JOIN LATERAL"
    end
  end

  describe "Analytics Dashboard Pattern from README" do
    test "Complex analytics query with multiple features" do
      selecto = configure_test_selecto()
      
      # Mock the helper functions
      generate_date_series = fn ->
        Selecto.select([{:generate_series, "2024-01-01", "2024-12-31", "1 day", as: "date"}])
      end
      
      calculate_metrics = fn ->
        Selecto.select([
          "date",
          {:sum, "revenue", as: "total_revenue"},
          {:count, "order_id", as: "order_count"},
          {:avg, "order_value", as: "avg_order_value"}
        ])
        |> Selecto.group_by(["date"])
      end
      
      get_top_products = fn ->
        Selecto.select(["product_name", "sales_count"])
        |> Selecto.order_by([{"sales_count", :desc}])
        |> Selecto.limit(5)
      end
      
      result = 
        selecto
        |> Selecto.with_cte("date_series", generate_date_series)
        |> Selecto.with_cte("metrics", calculate_metrics)
        |> Selecto.select([
            "date",
            {:json_build_object, [
              "revenue", "total_revenue",
              "orders", "order_count",
              "avg_order", "avg_order_value"
            ], as: "daily_metrics"},
            {:array_agg, "top_products", as: "bestsellers"}
          ])
        |> Selecto.lateral_join(:left, get_top_products, as: "top_products")
        |> Selecto.group_by(["date"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH date_series"
      assert sql =~ "WITH.*metrics"
      assert sql =~ "json_build_object"
      assert sql =~ "ARRAY_AGG.*top_products"
      assert sql =~ "LEFT JOIN LATERAL"
      assert sql =~ "GROUP BY.*date"
    end
  end

  describe "Hierarchical Data with Aggregation from README" do
    test "Category tree with product counts" do
      selecto = configure_test_selecto(:category)
      
      build_category_hierarchy = fn ->
        Selecto.with_recursive_cte("category_tree",
          base_query: fn ->
            Selecto.select(["category_id", "name", "parent_id", "0 AS level"])
            |> Selecto.filter([{"parent_id", nil}])
          end,
          recursive_query: fn cte ->
            Selecto.select([
              "c.category_id",
              "c.name",
              "c.parent_id",
              "#{cte}.level + 1"
            ])
            |> Selecto.from("category c")
            |> Selecto.join(:inner, cte, on: "c.parent_id = #{cte}.category_id")
          end
        )
      end
      
      get_category_products = fn ->
        Selecto.select([{:json_build_object, ["id", "product_id", "name", "product_name"], as: "product_info"}])
        |> Selecto.from("product")
        |> Selecto.filter([{"category_id", {:ref, "category_tree.category_id"}}])
      end
      
      result = 
        selecto
        |> build_category_hierarchy.()
        |> Selecto.select([
            "path",
            {:case_when, [
                {[{"level", 0}], "Root"},
                {[{"level", 1}], "Main Category"},
                {[true], "Subcategory"}
              ], as: "category_type"},
            {:json_agg, "product_info", as: "products"}
          ])
        |> Selecto.lateral_join(:left, 
            get_category_products, 
            as: "product_info")
        |> Selecto.group_by(["category_id", "path", "level"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH RECURSIVE category_tree"
      assert sql =~ "CASE WHEN level = 0"
      assert sql =~ "json_agg.*product_info"
      assert sql =~ "LEFT JOIN LATERAL"
      assert sql =~ "GROUP BY.*category_id.*path.*level"
    end
  end

  describe "Dynamic Filtering and Transformation from README" do
    test "Complex filtering with multiple conditions" do
      selecto = configure_test_selecto(:product)
      user_interests = ["electronics", "gadgets", "tech"]
      current_user = 123
      
      result = 
        selecto
        |> Selecto.filter([
            {:jsonb_path_exists, "attributes", "$.features[*] ? (@.enabled == true)"},
            {:array_overlap, "tags", user_interests},
            {:case_when, [
                {[{"user_role", "admin"}], true},
                {[{"visibility", "public"}], true},
                {[{"owner_id", current_user}], true}
              ], else: false}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "jsonb_path_exists"
      assert sql =~ "$.features[*] ? (@.enabled == true)"
      assert sql =~ "tags && $"
      assert sql =~ "CASE"
      assert sql =~ "user_role = 'admin'"
      assert sql =~ "visibility = 'public'"
      assert sql =~ "owner_id = $"
      assert user_interests in params
      assert current_user in params
    end
  end

  describe "Migration Guide Example from README" do
    test "Converted query from raw SQL to Selecto" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.with_cte("active_users", fn ->
            Selecto.filter([{"active", true}])
          end)
        |> Selecto.select([
            "u.name",
            {:array_agg, "r.role", as: "roles"},
            {:json_get_text, "u.metadata", "department", as: "dept"}
          ])
        |> Selecto.from("active_users AS u")
        |> Selecto.lateral_join(:cross, fn base ->
            Selecto.select(["role"])
            |> Selecto.from("user_roles")
            |> Selecto.filter([{"user_id", {:ref, "u.id"}}])
            |> Selecto.limit(5)
          end, as: "r")
        |> Selecto.group_by(["u.id", "u.name", "u.metadata"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH active_users AS"
      assert sql =~ "active = true"
      assert sql =~ "ARRAY_AGG.*r.role"
      assert sql =~ "u.metadata->>'department'"
      assert sql =~ "CROSS JOIN LATERAL"
      assert sql =~ "user_id = u.id"
      assert sql =~ "LIMIT 5"
      assert sql =~ "GROUP BY u.id, u.name, u.metadata"
    end
  end
end