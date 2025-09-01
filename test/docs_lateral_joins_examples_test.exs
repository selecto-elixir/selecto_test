defmodule DocsLateralJoinsExamplesTest do
  use ExUnit.Case, async: true
  
  defp configure_test_selecto(domain \\ :customer) do
    domain_config = %{
      root_schema: case domain do
        :customer -> SelectoTest.Store.Customer
        :order -> SelectoTest.Store.Order
        :product -> SelectoTest.Store.Product
        :film -> SelectoTest.Store.Film
        _ -> SelectoTest.Store.Customer
      end,
      tables: %{},
      columns: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end

  describe "Basic LATERAL Joins from Docs" do
    test "simple correlated subquery - recent orders per customer" do
      selecto = configure_test_selecto(:customer)
      connection = :test_connection
      order_domain = SelectoTest.Store.Order
      
      result = 
        selecto
        |> Selecto.select([
            "customer.name",
            "recent_orders.order_id",
            "recent_orders.order_date",
            "recent_orders.total"
          ])
        |> Selecto.lateral_join(
            :left,
            fn base ->
              Selecto.configure(order_domain, connection)
              |> Selecto.select(["order_id", "order_date", "total"])
              |> Selecto.filter([{"customer_id", {:ref, "customer.customer_id"}}])
              |> Selecto.order_by([{"order_date", :desc}])
              |> Selecto.limit(3)
            end,
            as: "recent_orders"
          )
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN LATERAL"
      assert sql =~ "SELECT order_id, order_date, total"
      assert sql =~ "WHERE customer_id = customer\\.customer_id"
      assert sql =~ "ORDER BY order_date DESC"
      assert sql =~ "LIMIT \\$"
      assert sql =~ "AS recent_orders"
      assert 3 in params
    end

    test "multiple column references for similar products" do
      selecto = configure_test_selecto(:customer)
      connection = :test_connection
      product_domain = SelectoTest.Store.Product
      
      result = 
        selecto
        |> Selecto.select([
            "customer.name",
            "similar_products.product_name",
            "similar_products.similarity_score"
          ])
        |> Selecto.lateral_join(
            :left,
            fn base ->
              Selecto.configure(product_domain, connection)
              |> Selecto.select([
                  "product.name AS product_name",
                  "similarity_score"
                ])
              |> Selecto.from("""
                  product,
                  LATERAL (
                    SELECT AVG(
                      CASE 
                        WHEN p2.category = product.category THEN 0.5
                        WHEN p2.brand = product.brand THEN 0.3
                        ELSE 0.1
                      END
                    ) AS similarity_score
                    FROM orders o
                    JOIN order_items oi ON o.order_id = oi.order_id
                    JOIN product p2 ON oi.product_id = p2.product_id
                    WHERE o.customer_id = customer.customer_id
                  ) sim
                """)
              |> Selecto.filter([
                  {"similarity_score", {:>, 0.3}},
                  {:not_in, "product.product_id", 
                    {:subquery, fn ->
                      # Products already purchased
                      Selecto.select(["DISTINCT oi.product_id"])
                      |> Selecto.from("orders o")
                      |> Selecto.join(:inner, "order_items oi", on: "o.order_id = oi.order_id")
                      |> Selecto.filter([{"o.customer_id", {:ref, "customer.customer_id"}}])
                    end}}
                ])
              |> Selecto.order_by([{"similarity_score", :desc}])
              |> Selecto.limit(5)
            end,
            as: "similar_products"
          )
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN LATERAL"
      assert sql =~ "product\\.name AS product_name"
      assert sql =~ "similarity_score"
      assert sql =~ "CASE"
      assert sql =~ "WHEN p2\\.category = product\\.category THEN"
      assert sql =~ "WHERE o\\.customer_id = customer\\.customer_id"
      assert sql =~ "similarity_score > \\$"
      assert sql =~ "NOT IN"
      assert sql =~ "ORDER BY similarity_score DESC"
      assert sql =~ "LIMIT \\$"
      assert 0.3 in params
      assert 5 in params
    end
  end

  describe "LATERAL with Aggregations from Docs" do
    test "aggregated statistics for each entity" do
      selecto = configure_test_selecto(:film)
      
      result = 
        selecto
        |> Selecto.select([
            "film.title",
            "film.release_year",
            "rental_stats.total_rentals",
            "rental_stats.total_revenue",
            "rental_stats.avg_rental_duration"
          ])
        |> Selecto.lateral_join(
            :left,
            fn base ->
              Selecto.from("rental r")
              |> Selecto.join(:inner, "inventory i", on: "r.inventory_id = i.inventory_id")
              |> Selecto.select([
                  {:count, "*", as: "total_rentals"},
                  {:sum, "r.amount", as: "total_revenue"},
                  {:avg, "EXTRACT(EPOCH FROM (r.return_date - r.rental_date))/86400", as: "avg_rental_duration"}
                ])
              |> Selecto.filter([{"i.film_id", {:ref, "film.film_id"}}])
            end,
            as: "rental_stats"
          )
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "LEFT JOIN LATERAL"
      assert sql =~ "COUNT\\(\\*\\) AS total_rentals"
      assert sql =~ "SUM\\(r\\.amount\\) AS total_revenue"
      assert sql =~ "AVG.*EXTRACT\\(EPOCH FROM.*AS avg_rental_duration"
      assert sql =~ "WHERE i\\.film_id = film\\.film_id"
      assert sql =~ "AS rental_stats"
    end
  end
end