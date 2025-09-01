defmodule DocsSubqueriesSubfiltersExamplesTest do
  use ExUnit.Case, async: true
  
  alias Selecto.Builder.Sql
  
  # Helper to configure test Selecto instance
  defp configure_test_selecto(table \\ "customer") do
    domain_config = %{
      source: %{
        module: SelectoTest.Store.Customer,
        table: table
      },
      schemas: %{
        "customer" => SelectoTest.Store.Customer,
        "orders" => SelectoTest.Store.Order,
        "payments" => SelectoTest.Store.Payment,
        "product" => SelectoTest.Store.Product,
        "reviews" => SelectoTest.Store.Review,
        "products" => SelectoTest.Store.Product,
        "employees" => SelectoTest.Store.Employee,
        "customers" => SelectoTest.Store.Customer,
        "order_items" => SelectoTest.Store.OrderItem,
        "supplier" => SelectoTest.Store.Supplier,
        "supplier_issues" => SelectoTest.Store.SupplierIssue,
        "users" => SelectoTest.Store.User,
        "user_activity" => SelectoTest.Store.UserActivity,
        "posts" => SelectoTest.Store.Post,
        "comments" => SelectoTest.Store.Comment,
        "videos" => SelectoTest.Store.Video,
        "region_stats" => SelectoTest.Store.RegionStat,
        "global_avg" => SelectoTest.Store.GlobalAvg,
        "city_customers" => SelectoTest.Store.CityCustomer,
        "country_customers" => SelectoTest.Store.CountryCustomer
      },
      joins: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end
  
  describe "Scalar Subqueries" do
    test "subqueries in SELECT with count and sum" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "customer.name",
            "customer.email",
            {:subquery, fn ->
              Selecto.select([{:count, "*"}])
              |> Selecto.from("orders")
              |> Selecto.filter([{"customer_id", {:ref, "customer.id"}}])
            end, as: "order_count"},
            {:subquery, fn ->
              Selecto.select([{:sum, "amount"}])
              |> Selecto.from("payments")
              |> Selecto.filter([{"customer_id", {:ref, "customer.id"}}])
            end, as: "total_spent"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "customer.name"
      assert sql =~ "customer.email"
      assert sql =~ "(SELECT COUNT(*) FROM orders WHERE customer_id = customer.id) AS order_count"
      assert sql =~ "(SELECT SUM(amount) FROM payments WHERE customer_id = customer.id) AS total_spent"
    end
    
    test "subquery with COALESCE for null handling" do
      selecto = configure_test_selecto("product")
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:coalesce, [
              {:subquery, fn ->
                Selecto.select([{:avg, "rating"}])
                |> Selecto.from("reviews")
                |> Selecto.filter([{"product_id", {:ref, "product.id"}}])
              end},
              0
            ], as: "avg_rating"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "product.name"
      assert sql =~ "COALESCE"
      assert sql =~ "SELECT AVG(rating) FROM reviews WHERE product_id = product.id"
      assert sql =~ "AS avg_rating"
      assert 0 in params
    end
    
    test "filter using subquery result" do
      selecto = configure_test_selecto("product")
      
      result = 
        selecto
        |> Selecto.select(["product.*"])
        |> Selecto.filter([
            {"price", {:<, 
              {:subquery, fn ->
                Selecto.select([{:avg, "price"}])
                |> Selecto.from("products")
                |> Selecto.filter([{"category", {:ref, "product.category"}}])
              end}
            }}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "product.*"
      assert sql =~ "price <"
      assert sql =~ "(SELECT AVG(price) FROM products WHERE category = product.category)"
    end
    
    test "multiple subquery conditions" do
      selecto = configure_test_selecto("employees")
      
      result = 
        selecto
        |> Selecto.select(["employee.*"])
        |> Selecto.filter([
            {"salary", {:>, 
              {:subquery, fn ->
                Selecto.select([{:avg, "salary"}])
                |> Selecto.from("employees AS e2")
                |> Selecto.filter([{"e2.department", {:ref, "employee.department"}}])
              end}
            }},
            {"hire_date", {:<,
              {:subquery, fn ->
                Selecto.select([{:min, "hire_date"}])
                |> Selecto.from("employees AS e3")
                |> Selecto.filter([{"e3.manager_id", {:ref, "employee.manager_id"}}])
              end}
            }}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "salary >"
      assert sql =~ "SELECT AVG(salary) FROM employees AS e2"
      assert sql =~ "e2.department = employee.department"
      assert sql =~ "hire_date <"
      assert sql =~ "SELECT MIN(hire_date) FROM employees AS e3"
      assert sql =~ "e3.manager_id = employee.manager_id"
    end
  end
  
  describe "Subqueries in FROM Clause" do
    test "using subquery as table source" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.from({:subquery, fn ->
            Selecto.select([
                "category",
                {:count, "*", as: "product_count"},
                {:avg, "price", as: "avg_price"}
              ])
            |> Selecto.from("products")
            |> Selecto.group_by(["category"])
            |> Selecto.having([{"product_count", {:>, 5}}])
          end, as: "category_stats"})
        |> Selecto.select([
            "category",
            "product_count",
            "avg_price",
            {:rank, over: "ORDER BY avg_price DESC", as: "price_rank"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "FROM (SELECT"
      assert sql =~ "COUNT(*) AS product_count"
      assert sql =~ "AVG(price) AS avg_price"
      assert sql =~ "GROUP BY category"
      assert sql =~ "HAVING product_count > $"
      assert sql =~ ") AS category_stats"
      assert sql =~ "RANK() OVER (ORDER BY avg_price DESC)"
      assert 5 in params
    end
    
    test "join with subquery" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select(["c.name", "recent_orders.order_count"])
        |> Selecto.from("customers AS c")
        |> Selecto.join(:left,
            {:subquery, fn ->
              Selecto.select([
                  "customer_id",
                  {:count, "*", as: "order_count"}
                ])
              |> Selecto.from("orders")
              |> Selecto.filter([{"order_date", {:>, "2024-01-01"}}])
              |> Selecto.group_by(["customer_id"])
            end, as: "recent_orders"},
            on: "c.id = recent_orders.customer_id"
          )
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "FROM customers AS c"
      assert sql =~ "LEFT JOIN"
      assert sql =~ "(SELECT customer_id, COUNT(*) AS order_count"
      assert sql =~ "WHERE order_date > '2024-01-01'"
      assert sql =~ "GROUP BY customer_id"
      assert sql =~ ") AS recent_orders"
      assert sql =~ "ON c.id = recent_orders.customer_id"
    end
  end
  
  describe "EXISTS and NOT EXISTS" do
    test "EXISTS pattern" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["customer.*"])
        |> Selecto.filter([
            {:exists, fn ->
              Selecto.from("orders")
              |> Selecto.filter([
                  {"customer_id", {:ref, "customer.id"}},
                  {"status", "completed"},
                  {"order_date", {:>, "2024-01-01"}}
                ])
            end}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "EXISTS"
      assert sql =~ "SELECT * FROM orders"
      assert sql =~ "customer_id = customer.id"
      assert sql =~ "status = $"
      assert sql =~ "order_date > '2024-01-01'"
      assert "completed" in params
    end
    
    test "NOT EXISTS pattern" do
      selecto = configure_test_selecto("product")
      
      result = 
        selecto
        |> Selecto.select(["product.*"])
        |> Selecto.filter([
            {:not_exists, fn ->
              Selecto.from("order_items")
              |> Selecto.filter([
                  {"product_id", {:ref, "product.id"}},
                  {"created_at", {:>, "CURRENT_DATE - INTERVAL '90 days'"}}
                ])
            end}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "NOT EXISTS"
      assert sql =~ "SELECT * FROM order_items"
      assert sql =~ "product_id = product.id"
      assert sql =~ "created_at > 'CURRENT_DATE - INTERVAL '90 days'"
    end
    
    test "multiple EXISTS conditions" do
      selecto = configure_test_selecto("supplier")
      
      result = 
        selecto
        |> Selecto.select(["supplier.*"])
        |> Selecto.filter([
            {:exists, fn ->
              Selecto.from("products")
              |> Selecto.filter([
                  {"supplier_id", {:ref, "supplier.id"}},
                  {"in_stock", true}
                ])
            end},
            {:not_exists, fn ->
              Selecto.from("supplier_issues")
              |> Selecto.filter([
                  {"supplier_id", {:ref, "supplier.id"}},
                  {"resolved", false}
                ])
            end}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "EXISTS"
      assert sql =~ "SELECT * FROM products"
      assert sql =~ "supplier_id = supplier.id"
      assert sql =~ "in_stock = $"
      assert sql =~ "NOT EXISTS"
      assert sql =~ "SELECT * FROM supplier_issues"
      assert sql =~ "resolved = $"
      assert true in params
      assert false in params
    end
  end
  
  describe "IN and NOT IN" do
    test "IN with subquery" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select(["*"])
        |> Selecto.filter([
            {"id", {:in, 
              {:subquery, fn ->
                Selecto.select(["DISTINCT customer_id"])
                |> Selecto.from("orders")
                |> Selecto.filter([
                    {"total", {:>, 1000}},
                    {"status", "completed"}
                  ])
              end}
            }}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "id IN"
      assert sql =~ "(SELECT DISTINCT customer_id FROM orders"
      assert sql =~ "total > $"
      assert sql =~ "status = $"
      assert 1000 in params
      assert "completed" in params
    end
    
    test "NOT IN with subquery" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.select(["*"])
        |> Selecto.filter([
            {"id", {:not_in,
              {:subquery, fn ->
                Selecto.select(["product_id"])
                |> Selecto.from("discontinued_products")
              end}
            }}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "id NOT IN"
      assert sql =~ "(SELECT product_id FROM discontinued_products)"
    end
  end
  
  describe "ANY, ALL, and SOME" do
    test "ANY operator with subquery" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.select(["*"])
        |> Selecto.filter([
            {"price", {:<, 
              {:any, fn ->
                Selecto.select(["price"])
                |> Selecto.from("competitor_products")
                |> Selecto.filter([{"category", {:ref, "products.category"}}])
              end}
            }}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "price < ANY"
      assert sql =~ "(SELECT price FROM competitor_products"
      assert sql =~ "category = products.category"
    end
    
    test "ALL operator with subquery" do
      selecto = configure_test_selecto("employees")
      
      result = 
        selecto
        |> Selecto.select(["*"])
        |> Selecto.filter([
            {"salary", {:>,
              {:all, fn ->
                Selecto.select(["salary"])
                |> Selecto.from("employees AS e2")
                |> Selecto.filter([{"e2.department", "Sales"}])
              end}
            }}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "salary > ALL"
      assert sql =~ "(SELECT salary FROM employees AS e2"
      assert sql =~ "e2.department = $"
      assert "Sales" in params
    end
  end
  
  describe "Correlated Subqueries" do
    test "correlated subquery in SELECT" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select([
            "c.name",
            {:subquery, fn ->
              Selecto.select([{:max, "order_date"}])
              |> Selecto.from("orders AS o")
              |> Selecto.filter([{"o.customer_id", {:ref, "c.id"}}])
            end, as: "last_order_date"}
          ])
        |> Selecto.from("customers AS c")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "c.name"
      assert sql =~ "(SELECT MAX(order_date) FROM orders AS o WHERE o.customer_id = c.id) AS last_order_date"
    end
    
    test "correlated subquery with multiple references" do
      selecto = configure_test_selecto("employees")
      
      result = 
        selecto
        |> Selecto.select(["e1.*"])
        |> Selecto.from("employees AS e1")
        |> Selecto.filter([
            {"salary", {:>,
              {:subquery, fn ->
                Selecto.select([{:percentile_cont, 0.75, "WITHIN GROUP (ORDER BY salary)"}])
                |> Selecto.from("employees AS e2")
                |> Selecto.filter([
                    {"e2.department", {:ref, "e1.department"}},
                    {"e2.location", {:ref, "e1.location"}}
                  ])
              end}
            }}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "FROM employees AS e1"
      assert sql =~ "salary >"
      assert sql =~ "PERCENTILE_CONT($) WITHIN GROUP (ORDER BY salary)"
      assert sql =~ "e2.department = e1.department"
      assert sql =~ "e2.location = e1.location"
      assert 0.75 in params
    end
  end
  
  describe "Subfilters System" do
    test "basic subfilter on joined table" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.join(:inner, "orders", on: "customers.id = orders.customer_id")
        |> Selecto.subfilter("orders", [
            {"status", "completed"},
            {"total", {:>, 100}}
          ])
        |> Selecto.select(["customers.name", "orders.total"])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "INNER JOIN orders"
      assert sql =~ "customers.id = orders.customer_id"
      assert sql =~ "orders.status = $"
      assert sql =~ "orders.total > $"
      assert "completed" in params
      assert 100 in params
    end
    
    test "multiple subfilters on different joins" do
      selecto = configure_test_selecto("users")
      
      result = 
        selecto
        |> Selecto.join(:left, "posts", on: "users.id = posts.user_id")
        |> Selecto.join(:left, "comments", on: "posts.id = comments.post_id")
        |> Selecto.subfilter("posts", [
            {"published", true},
            {"created_at", {:>, "2024-01-01"}}
          ])
        |> Selecto.subfilter("comments", [
            {"approved", true}
          ])
        |> Selecto.select(["users.name", {:count, "DISTINCT posts.id", as: "post_count"}])
        |> Selecto.group_by(["users.id", "users.name"])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN posts"
      assert sql =~ "LEFT JOIN comments"
      assert sql =~ "posts.published = $"
      assert sql =~ "posts.created_at > '2024-01-01'"
      assert sql =~ "comments.approved = $"
      assert sql =~ "COUNT(DISTINCT posts.id)"
      assert sql =~ "GROUP BY users.id, users.name"
      assert true in params
    end
  end
  
  describe "Advanced Patterns" do
    test "recursive subquery pattern" do
      selecto = configure_test_selecto("employees")
      
      result = 
        selecto
        |> Selecto.with_recursive_cte("org_tree",
            base_query: fn ->
              Selecto.select(["id", "name", "manager_id", {:literal, 0, as: "level"}])
              |> Selecto.from("employees")
              |> Selecto.filter([{"manager_id", nil}])
            end,
            recursive_query: fn cte ->
              Selecto.select([
                  "e.id",
                  "e.name",
                  "e.manager_id",
                  "#{cte}.level + 1"
                ])
              |> Selecto.from("employees AS e")
              |> Selecto.join(:inner, "#{cte}", on: "e.manager_id = #{cte}.id")
            end
          )
        |> Selecto.select(["*"])
        |> Selecto.from("org_tree")
        |> Selecto.filter([{"level", {:<=, 3}}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "WITH RECURSIVE org_tree"
      assert sql =~ "manager_id IS NULL"
      assert sql =~ "UNION"
      assert sql =~ "e.manager_id = org_tree.id"
      assert sql =~ "level <= $"
      assert 0 in params
      assert 3 in params
    end
    
    test "window function with subquery" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.select([
            "name",
            "price",
            "category",
            {:subquery, fn ->
              Selecto.select([{:avg, "price"}])
              |> Selecto.from("products AS p2")
              |> Selecto.filter([{"p2.category", {:ref, "products.category"}}])
            end, as: "category_avg"},
            {:rank, over: "PARTITION BY category ORDER BY price DESC", as: "price_rank"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "name"
      assert sql =~ "price"
      assert sql =~ "(SELECT AVG(price) FROM products AS p2 WHERE p2.category = products.category) AS category_avg"
      assert sql =~ "RANK() OVER (PARTITION BY category ORDER BY price DESC)"
    end
  end
  
  describe "Performance Patterns" do
    test "EXISTS instead of IN for better performance" do
      selecto = configure_test_selecto("customers")
      
      # Better performance with EXISTS
      result = 
        selecto
        |> Selecto.select(["*"])
        |> Selecto.filter([
            {:exists, fn ->
              Selecto.from("orders")
              |> Selecto.filter([
                  {"customer_id", {:ref, "customers.id"}},
                  {"total", {:>, 1000}}
                ])
              |> Selecto.limit(1)  # Optimization: stop at first match
            end}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "EXISTS"
      assert sql =~ "customer_id = customers.id"
      assert sql =~ "total > $"
      assert sql =~ "LIMIT 1"
      assert 1000 in params
    end
    
    test "pushing down filters in subqueries" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.from({:subquery, fn ->
            Selecto.select(["user_id", {:count, "*", as: "activity_count"}])
            |> Selecto.from("user_activity")
            |> Selecto.filter([
                {"timestamp", {:>=, "2024-01-01"}},  # Push down filter
                {"event_type", {:in, ["login", "purchase", "view"]}}  # Push down filter
              ])
            |> Selecto.group_by(["user_id"])
          end, as: "user_stats"})
        |> Selecto.select(["*"])
        |> Selecto.filter([{"activity_count", {:>, 10}}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "timestamp >= '2024-01-01'"
      assert sql =~ "event_type IN"
      assert sql =~ "GROUP BY user_id"
      assert sql =~ "activity_count > $"
      assert ["login", "purchase", "view"] in params
      assert 10 in params
    end
  end
  
  describe "Complex Nested Patterns" do
    test "nested subqueries" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.select(["*"])
        |> Selecto.filter([
            {"price", {:<,
              {:subquery, fn ->
                Selecto.select([{:avg, "price"}])
                |> Selecto.from("products AS p2")
                |> Selecto.filter([
                    {"p2.category", {:ref, "products.category"}},
                    {"p2.id", {:in,
                      {:subquery, fn ->
                        Selecto.select(["product_id"])
                        |> Selecto.from("featured_products")
                        |> Selecto.filter([{"active", true}])
                      end}
                    }}
                  ])
              end}
            }}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "price <"
      assert sql =~ "SELECT AVG(price)"
      assert sql =~ "p2.category = products.category"
      assert sql =~ "p2.id IN"
      assert sql =~ "SELECT product_id FROM featured_products"
      assert sql =~ "active = $"
      assert true in params
    end
    
    test "subquery with CASE expression" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select([
            "name",
            {:case_when, [
                {[{:exists, fn ->
                  Selecto.from("orders")
                  |> Selecto.filter([
                      {"customer_id", {:ref, "customers.id"}},
                      {"total", {:>, 10000}}
                    ])
                end}], "VIP"},
                {[{:exists, fn ->
                  Selecto.from("orders")
                  |> Selecto.filter([
                      {"customer_id", {:ref, "customers.id"}},
                      {"total", {:>, 1000}}
                    ])
                end}], "Premium"},
                {[true], "Regular"}
              ], as: "customer_tier"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "WHEN EXISTS"
      assert sql =~ "total > $"
      assert sql =~ "THEN 'VIP'"
      assert sql =~ "THEN 'Premium'"
      assert sql =~ "ELSE 'Regular'"
      assert 10000 in params
      assert 1000 in params
      assert "VIP" in params
      assert "Premium" in params
      assert "Regular" in params
    end
  end
end