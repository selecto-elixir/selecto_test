defmodule DocsCteExamplesTest do
  use ExUnit.Case, async: true
  
  defp configure_test_selecto(domain \\ :customer) do
    domain_config = %{
      root_schema: case domain do
        :customer -> SelectoTest.Store.Customer
        :payment -> SelectoTest.Store.Payment
        :rental -> SelectoTest.Store.Rental
        :film -> SelectoTest.Store.Film
        :sales -> SelectoTest.Store.Sales
        :employee -> SelectoTest.Store.Employee
        _ -> SelectoTest.Store.Customer
      end,
      tables: %{},
      columns: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end

  describe "Basic CTEs from Docs" do
    test "basic CTE for data filtering" do
      selecto = configure_test_selecto(:customer)
      connection = :test_connection
      customer_domain = SelectoTest.Store.Customer
      
      result = 
        selecto
        |> Selecto.with_cte("active_customers", fn ->
            Selecto.configure(customer_domain, connection)
            |> Selecto.select(["customer_id", "first_name", "last_name", "email"])
            |> Selecto.filter([{"active", true}])
            |> Selecto.filter([{"created_at", {:>, "2023-01-01"}}])
          end)
        |> Selecto.select(["active_customers.*"])
        |> Selecto.from("active_customers")
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH active_customers AS"
      assert sql =~ "SELECT customer_id, first_name, last_name, email"
      assert sql =~ "WHERE active = true"
      assert sql =~ "AND created_at > \\$"
      assert sql =~ "SELECT active_customers\\.\\*"
      assert sql =~ "FROM active_customers"
      assert "2023-01-01" in params
    end

    test "CTE with aggregation" do
      selecto = configure_test_selecto(:customer)
      connection = :test_connection
      payment_domain = SelectoTest.Store.Payment
      
      result = 
        selecto
        |> Selecto.with_cte("customer_stats", fn ->
            Selecto.configure(payment_domain, connection)
            |> Selecto.select([
                "customer_id",
                {:sum, "amount", as: "total_spent"},
                {:count, "*", as: "payment_count"},
                {:avg, "amount", as: "avg_payment"}
              ])
            |> Selecto.group_by(["customer_id"])
            |> Selecto.having([{"total_spent", {:>, 1000}}])
          end)
        |> Selecto.select(["customer.name", "stats.total_spent", "stats.payment_count"])
        |> Selecto.join(:inner, "customer_stats AS stats", 
            on: "customer.customer_id = stats.customer_id")
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH customer_stats AS"
      assert sql =~ "SUM\\(amount\\) AS total_spent"
      assert sql =~ "COUNT\\(\\*\\) AS payment_count"
      assert sql =~ "AVG\\(amount\\) AS avg_payment"
      assert sql =~ "GROUP BY customer_id"
      assert sql =~ "HAVING.*total_spent > \\$"
      assert sql =~ "INNER JOIN customer_stats AS stats"
      assert 1000 in params
    end

    test "CTE with joins and subqueries" do
      selecto = configure_test_selecto(:customer)
      connection = :test_connection
      rental_domain = SelectoTest.Store.Rental
      
      result = 
        selecto
        |> Selecto.with_cte("recent_rentals", fn ->
            Selecto.configure(rental_domain, connection)
            |> Selecto.select([
                "rental.customer_id",
                "film.title",
                "film.rating",
                "rental.rental_date"
              ])
            |> Selecto.join(:inner, "inventory", on: "rental.inventory_id = inventory.inventory_id")
            |> Selecto.join(:inner, "film", on: "inventory.film_id = film.film_id")
            |> Selecto.filter([{"rental.rental_date", {:>, "CURRENT_DATE - INTERVAL '30 days'"}}])
            |> Selecto.order_by([{"rental.rental_date", :desc}])
          end)
        |> Selecto.select([
            "customer.first_name",
            "customer.last_name",
            {:array_agg, "recent_rentals.title", as: "recent_films"}
          ])
        |> Selecto.join(:inner, "recent_rentals", 
            on: "customer.customer_id = recent_rentals.customer_id")
        |> Selecto.group_by(["customer.customer_id", "customer.first_name", "customer.last_name"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH recent_rentals AS"
      assert sql =~ "SELECT.*rental\\.customer_id.*film\\.title.*film\\.rating.*rental\\.rental_date"
      assert sql =~ "INNER JOIN inventory"
      assert sql =~ "INNER JOIN film"
      assert sql =~ "rental\\.rental_date > CURRENT_DATE - INTERVAL '30 days'"
      assert sql =~ "ORDER BY rental\\.rental_date DESC"
      assert sql =~ "ARRAY_AGG.*recent_rentals\\.title.*AS recent_films"
      assert sql =~ "GROUP BY customer\\.customer_id"
    end
  end

  describe "Multiple CTEs from Docs" do
    test "multiple independent CTEs" do
      selecto = configure_test_selecto(:rental)
      connection = :test_connection
      customer_domain = SelectoTest.Store.Customer
      film_domain = SelectoTest.Store.Film
      
      result = 
        selecto
        |> Selecto.with_ctes([
            {"high_value_customers", fn ->
              Selecto.configure(customer_domain, connection)
              |> Selecto.select(["customer_id", "first_name", "last_name"])
              |> Selecto.aggregate([{"payment.amount", :sum, as: "total_spent"}])
              |> Selecto.join(:inner, "payment", on: "customer.customer_id = payment.customer_id")
              |> Selecto.group_by(["customer.customer_id", "customer.first_name", "customer.last_name"])
              |> Selecto.having([{"total_spent", {:>, 200}}])
            end},
            
            {"popular_films", fn ->
              Selecto.configure(film_domain, connection)
              |> Selecto.select(["film_id", "title", "rating"])
              |> Selecto.aggregate([{"rental.rental_id", :count, as: "rental_count"}])
              |> Selecto.join(:inner, "inventory", on: "film.film_id = inventory.film_id")
              |> Selecto.join(:inner, "rental", on: "inventory.inventory_id = rental.inventory_id")
              |> Selecto.group_by(["film.film_id", "film.title", "film.rating"])
              |> Selecto.having([{"rental_count", {:>, 30}}])
            end}
          ])
        |> Selecto.select([
            "high_value_customers.first_name",
            "popular_films.title",
            "rental.rental_date"
          ])
        |> Selecto.join(:inner, "high_value_customers", 
            on: "rental.customer_id = high_value_customers.customer_id")
        |> Selecto.join(:inner, "inventory", on: "rental.inventory_id = inventory.inventory_id")
        |> Selecto.join(:inner, "popular_films", on: "inventory.film_id = popular_films.film_id")
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH high_value_customers AS"
      assert sql =~ "WITH.*popular_films AS" or sql =~ ", popular_films AS"
      assert sql =~ "SUM.*payment\\.amount.*AS total_spent"
      assert sql =~ "COUNT.*rental\\.rental_id.*AS rental_count"
      assert sql =~ "HAVING.*total_spent > \\$"
      assert sql =~ "HAVING.*rental_count > \\$"
      assert 200 in params
      assert 30 in params
    end

    test "dependent CTEs referencing other CTEs" do
      selecto = configure_test_selecto(:sales)
      connection = :test_connection
      sales_domain = SelectoTest.Store.Sales
      
      result = 
        selecto
        |> Selecto.with_cte("base_data", fn ->
            Selecto.configure(sales_domain, connection)
            |> Selecto.select(["product_id", "sale_date", "quantity", "price"])
            |> Selecto.filter([{"sale_date", {:>=, "2024-01-01"}}])
          end)
        |> Selecto.with_cte("daily_totals", fn ->
            # References base_data CTE
            Selecto.from("base_data")
            |> Selecto.select([
                "sale_date",
                {:sum, "quantity * price", as: "daily_revenue"},
                {:sum, "quantity", as: "units_sold"}
              ])
            |> Selecto.group_by(["sale_date"])
          end)
        |> Selecto.with_cte("running_totals", fn ->
            # References daily_totals CTE
            Selecto.from("daily_totals")
            |> Selecto.select([
                "sale_date",
                "daily_revenue",
                "units_sold",
                {:sum, "daily_revenue", 
                  over: "ORDER BY sale_date", 
                  as: "cumulative_revenue"}
              ])
          end)
        |> Selecto.select(["*"])
        |> Selecto.from("running_totals")
        |> Selecto.order_by([{"sale_date", :asc}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH base_data AS"
      assert sql =~ "sale_date >= \\$"
      assert sql =~ "WITH.*daily_totals AS" or sql =~ ", daily_totals AS"
      assert sql =~ "FROM base_data"
      assert sql =~ "SUM\\(quantity \\* price\\) AS daily_revenue"
      assert sql =~ "WITH.*running_totals AS" or sql =~ ", running_totals AS"
      assert sql =~ "FROM daily_totals"
      assert sql =~ "SUM\\(daily_revenue\\) OVER \\(ORDER BY sale_date\\) AS cumulative_revenue"
      assert sql =~ "FROM running_totals"
      assert sql =~ "ORDER BY sale_date ASC"
      assert "2024-01-01" in params
    end
  end

  describe "Recursive CTEs from Docs" do
    test "basic recursive CTE for employee hierarchy" do
      selecto = configure_test_selecto(:employee)
      connection = :test_connection
      employee_domain = SelectoTest.Store.Employee
      
      result = 
        selecto
        |> Selecto.with_recursive_cte("org_chart",
            # Base case: top-level employees
            base_query: fn ->
              Selecto.configure(employee_domain, connection)
              |> Selecto.select([
                  "employee_id",
                  "name",
                  "manager_id",
                  "0 AS level"
                ])
              |> Selecto.filter([{"manager_id", nil}])
            end,
            # Recursive case
            recursive_query: fn cte ->
              Selecto.configure(employee_domain, connection)
              |> Selecto.select([
                  "e.employee_id",
                  "e.name",
                  "e.manager_id",
                  "#{cte}.level + 1"
                ])
              |> Selecto.from("employee e")
              |> Selecto.join(:inner, cte, on: "e.manager_id = #{cte}.employee_id")
            end
          )
        |> Selecto.select(["*"])
        |> Selecto.from("org_chart")
        |> Selecto.order_by([{"level", :asc}, {"name", :asc}])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WITH RECURSIVE org_chart AS"
      assert sql =~ "SELECT employee_id.*name.*manager_id.*0 AS level"
      assert sql =~ "WHERE manager_id IS NULL"
      assert sql =~ "UNION"
      assert sql =~ "SELECT e\\.employee_id.*e\\.name.*e\\.manager_id.*org_chart\\.level \\+ 1"
      assert sql =~ "INNER JOIN org_chart ON e\\.manager_id = org_chart\\.employee_id"
      assert sql =~ "FROM org_chart"
      assert sql =~ "ORDER BY level ASC, name ASC"
    end
  end
end