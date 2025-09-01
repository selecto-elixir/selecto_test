defmodule DocsWindowFunctionsExamplesTest do
  use ExUnit.Case, async: true
  
  alias Selecto.Builder.Sql
  
  # Helper to configure test Selecto instance
  defp configure_test_selecto(table \\ "employee") do
    domain_config = %{
      source: %{
        module: SelectoTest.Store.Employee,
        table: table
      },
      schemas: %{
        "employee" => SelectoTest.Store.Employee,
        "employees" => SelectoTest.Store.Employee,
        "sale" => SelectoTest.Store.Sale,
        "sales" => SelectoTest.Store.Sale,
        "product" => SelectoTest.Store.Product,
        "products" => SelectoTest.Store.Product,
        "student" => SelectoTest.Store.Student,
        "students" => SelectoTest.Store.Student,
        "customer" => SelectoTest.Store.Customer,
        "customers" => SelectoTest.Store.Customer,
        "transaction" => SelectoTest.Store.Transaction,
        "transactions" => SelectoTest.Store.Transaction,
        "stock_prices" => SelectoTest.Store.StockPrice,
        "orders" => SelectoTest.Store.Order,
        "game_scores" => SelectoTest.Store.GameScore,
        "website_sessions" => SelectoTest.Store.WebsiteSession,
        "departments" => SelectoTest.Store.Department,
        "events" => SelectoTest.Store.Event,
        "metrics" => SelectoTest.Store.Metric,
        "regions" => SelectoTest.Store.Region,
        "revenue" => SelectoTest.Store.Revenue
      },
      joins: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end
  
  describe "Understanding Window Functions" do
    test "basic window function with partition" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "employee.name",
            "employee.salary",
            "employee.department",
            {:avg, "salary", over: "PARTITION BY department", as: "dept_avg_salary"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "employee.name"
      assert sql =~ "employee.salary"
      assert sql =~ "employee.department"
      assert sql =~ "AVG(salary) OVER (PARTITION BY department) AS dept_avg_salary"
    end
    
    test "window function with ordering" do
      selecto = configure_test_selecto("sale")
      
      result = 
        selecto
        |> Selecto.select([
            "sale.date",
            "sale.amount",
            {:sum, "amount", over: "ORDER BY date", as: "running_total"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "sale.date"
      assert sql =~ "sale.amount"
      assert sql =~ "SUM(amount) OVER (ORDER BY date) AS running_total"
    end
  end
  
  describe "Ranking Functions" do
    test "ROW_NUMBER with partition and order" do
      selecto = configure_test_selecto("product")
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            "product.category",
            "product.price",
            {:row_number, over: "PARTITION BY category ORDER BY price DESC", 
              as: "price_rank_in_category"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "product.name"
      assert sql =~ "product.category"
      assert sql =~ "product.price"
      assert sql =~ "ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC) AS price_rank_in_category"
    end
    
    test "RANK and DENSE_RANK comparison" do
      selecto = configure_test_selecto("student")
      
      result = 
        selecto
        |> Selecto.select([
            "student.name",
            "student.score",
            {:rank, over: "ORDER BY score DESC", as: "rank"},
            {:dense_rank, over: "ORDER BY score DESC", as: "dense_rank"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "student.name"
      assert sql =~ "student.score"
      assert sql =~ "RANK() OVER (ORDER BY score DESC) AS rank"
      assert sql =~ "DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rank"
    end
    
    test "percentile ranking functions" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "employee.name",
            "employee.salary",
            {:percent_rank, over: "ORDER BY salary", as: "salary_percentile"},
            {:cume_dist, over: "ORDER BY salary", as: "cumulative_distribution"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "employee.name"
      assert sql =~ "employee.salary"
      assert sql =~ "PERCENT_RANK() OVER (ORDER BY salary) AS salary_percentile"
      assert sql =~ "CUME_DIST() OVER (ORDER BY salary) AS cumulative_distribution"
    end
    
    test "NTILE for quartiles" do
      selecto = configure_test_selecto("customer")
      
      result = 
        selecto
        |> Selecto.select([
            "customer.name",
            "customer.total_spent",
            {:ntile, 4, over: "ORDER BY total_spent DESC", as: "spending_quartile"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "customer.name"
      assert sql =~ "customer.total_spent"
      assert sql =~ "NTILE($) OVER (ORDER BY total_spent DESC) AS spending_quartile"
      assert 4 in params
    end
    
    test "NTILE with CASE for performance tiers" do
      selecto = configure_test_selecto("product")
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            "product.revenue",
            {:ntile, 10, over: "ORDER BY revenue DESC", as: "revenue_decile"},
            {:case_when, [
                {[{:ntile, 10, over: "ORDER BY revenue DESC", lte: 2}], "Top 20%"},
                {[{:ntile, 10, over: "ORDER BY revenue DESC", lte: 5}], "Top 50%"},
                {[true], "Bottom 50%"}
              ], as: "performance_tier"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "product.name"
      assert sql =~ "product.revenue"
      assert sql =~ "NTILE($) OVER (ORDER BY revenue DESC) AS revenue_decile"
      assert sql =~ "CASE"
      assert sql =~ "WHEN NTILE($) OVER (ORDER BY revenue DESC) <= $"
      assert sql =~ "THEN 'Top 20%'"
      assert sql =~ "THEN 'Top 50%'"
      assert sql =~ "ELSE 'Bottom 50%'"
      assert 10 in params
      assert 2 in params
      assert 5 in params
      assert "Top 20%" in params
      assert "Top 50%" in params
      assert "Bottom 50%" in params
    end
  end
  
  describe "Aggregate Window Functions" do
    test "running aggregates" do
      selecto = configure_test_selecto("transaction")
      
      result = 
        selecto
        |> Selecto.select([
            "transaction.date",
            "transaction.amount",
            {:sum, "amount", over: "ORDER BY date", as: "running_sum"},
            {:avg, "amount", over: "ORDER BY date", as: "running_avg"},
            {:count, "*", over: "ORDER BY date", as: "running_count"},
            {:max, "amount", over: "ORDER BY date", as: "running_max"},
            {:min, "amount", over: "ORDER BY date", as: "running_min"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "transaction.date"
      assert sql =~ "transaction.amount"
      assert sql =~ "SUM(amount) OVER (ORDER BY date) AS running_sum"
      assert sql =~ "AVG(amount) OVER (ORDER BY date) AS running_avg"
      assert sql =~ "COUNT(*) OVER (ORDER BY date) AS running_count"
      assert sql =~ "MAX(amount) OVER (ORDER BY date) AS running_max"
      assert sql =~ "MIN(amount) OVER (ORDER BY date) AS running_min"
    end
    
    test "moving averages with frame specification" do
      selecto = configure_test_selecto("stock_prices")
      
      result = 
        selecto
        |> Selecto.select([
            "symbol",
            "date",
            "close_price",
            {:avg, "close_price", 
              over: "PARTITION BY symbol ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW",
              as: "moving_avg_7_day"},
            {:avg, "close_price",
              over: "PARTITION BY symbol ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW",
              as: "moving_avg_30_day"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "symbol"
      assert sql =~ "date"
      assert sql =~ "close_price"
      assert sql =~ "AVG(close_price) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7_day"
      assert sql =~ "AVG(close_price) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS moving_avg_30_day"
    end
  end
  
  describe "Value Functions" do
    test "LAG and LEAD functions" do
      selecto = configure_test_selecto("sales")
      
      result = 
        selecto
        |> Selecto.select([
            "month",
            "revenue",
            {:lag, "revenue", 1, over: "ORDER BY month", as: "prev_month_revenue"},
            {:lead, "revenue", 1, over: "ORDER BY month", as: "next_month_revenue"},
            {"revenue - LAG(revenue, 1) OVER (ORDER BY month) AS month_over_month_change"},
            {"(revenue - LAG(revenue, 1) OVER (ORDER BY month)) / LAG(revenue, 1) OVER (ORDER BY month) * 100 AS growth_rate"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "month"
      assert sql =~ "revenue"
      assert sql =~ "LAG(revenue, $) OVER (ORDER BY month) AS prev_month_revenue"
      assert sql =~ "LEAD(revenue, $) OVER (ORDER BY month) AS next_month_revenue"
      assert sql =~ "revenue - LAG(revenue, 1) OVER (ORDER BY month) AS month_over_month_change"
      assert sql =~ "growth_rate"
      assert 1 in params
    end
    
    test "FIRST_VALUE and LAST_VALUE" do
      selecto = configure_test_selecto("employees")
      
      result = 
        selecto
        |> Selecto.select([
            "department",
            "name",
            "salary",
            {:first_value, "name", 
              over: "PARTITION BY department ORDER BY salary DESC",
              as: "highest_paid_in_dept"},
            {:last_value, "name",
              over: "PARTITION BY department ORDER BY salary DESC RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING",
              as: "lowest_paid_in_dept"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "department"
      assert sql =~ "name"
      assert sql =~ "salary"
      assert sql =~ "FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC) AS highest_paid_in_dept"
      assert sql =~ "LAST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS lowest_paid_in_dept"
    end
    
    test "NTH_VALUE function" do
      selecto = configure_test_selecto("game_scores")
      
      result = 
        selecto
        |> Selecto.select([
            "player",
            "score",
            "game_date",
            {:nth_value, "score", 2,
              over: "PARTITION BY player ORDER BY score DESC",
              as: "second_best_score"},
            {:nth_value, "score", 3,
              over: "PARTITION BY player ORDER BY score DESC",
              as: "third_best_score"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "player"
      assert sql =~ "score"
      assert sql =~ "game_date"
      assert sql =~ "NTH_VALUE(score, $) OVER (PARTITION BY player ORDER BY score DESC) AS second_best_score"
      assert sql =~ "NTH_VALUE(score, $) OVER (PARTITION BY player ORDER BY score DESC) AS third_best_score"
      assert 2 in params
      assert 3 in params
    end
  end
  
  describe "Frame Specifications" do
    test "ROWS frame specification" do
      selecto = configure_test_selecto("transactions")
      
      result = 
        selecto
        |> Selecto.select([
            "date",
            "amount",
            {:sum, "amount",
              over: "ORDER BY date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING",
              as: "centered_sum_5"},
            {:avg, "amount",
              over: "ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW",
              as: "cumulative_avg"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "date"
      assert sql =~ "amount"
      assert sql =~ "SUM(amount) OVER (ORDER BY date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS centered_sum_5"
      assert sql =~ "AVG(amount) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_avg"
    end
    
    test "RANGE frame specification" do
      selecto = configure_test_selecto("events")
      
      result = 
        selecto
        |> Selecto.select([
            "timestamp",
            "value",
            {:sum, "value",
              over: "ORDER BY timestamp RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW",
              as: "hourly_sum"},
            {:count, "*",
              over: "ORDER BY timestamp RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND INTERVAL '24 hours' FOLLOWING",
              as: "daily_count"}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "timestamp"
      assert sql =~ "value"
      assert sql =~ "SUM(value) OVER (ORDER BY timestamp RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW) AS hourly_sum"
      assert sql =~ "COUNT(*) OVER (ORDER BY timestamp RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND INTERVAL '24 hours' FOLLOWING) AS daily_count"
    end
  end
  
  describe "Advanced Patterns" do
    test "year-over-year comparison" do
      selecto = configure_test_selecto("revenue")
      
      result = 
        selecto
        |> Selecto.select([
            "year",
            "month",
            "revenue",
            {:lag, "revenue", 12, over: "ORDER BY year, month", as: "revenue_last_year"},
            {"(revenue - LAG(revenue, 12) OVER (ORDER BY year, month)) / LAG(revenue, 12) OVER (ORDER BY year, month) * 100 AS yoy_growth"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "year"
      assert sql =~ "month"
      assert sql =~ "revenue"
      assert sql =~ "LAG(revenue, $) OVER (ORDER BY year, month) AS revenue_last_year"
      assert sql =~ "yoy_growth"
      assert 12 in params
    end
    
    test "sessionization with window functions" do
      selecto = configure_test_selecto("website_sessions")
      
      result = 
        selecto
        |> Selecto.select([
            "user_id",
            "event_time",
            "page_view",
            {:lag, "event_time", 1, over: "PARTITION BY user_id ORDER BY event_time", as: "prev_event_time"},
            {"CASE WHEN event_time - LAG(event_time, 1) OVER (PARTITION BY user_id ORDER BY event_time) > INTERVAL '30 minutes' 
              THEN 1 ELSE 0 END AS new_session_flag"},
            {:sum, "CASE WHEN event_time - LAG(event_time, 1) OVER (PARTITION BY user_id ORDER BY event_time) > INTERVAL '30 minutes' 
              THEN 1 ELSE 0 END", over: "PARTITION BY user_id ORDER BY event_time", as: "session_id"}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "user_id"
      assert sql =~ "event_time"
      assert sql =~ "page_view"
      assert sql =~ "LAG(event_time, $) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event_time"
      assert sql =~ "INTERVAL '30 minutes'"
      assert sql =~ "new_session_flag"
      assert sql =~ "session_id"
      assert 1 in params
    end
    
    test "top N per group" do
      selecto = configure_test_selecto("products")
      
      result = 
        selecto
        |> Selecto.with_cte("ranked_products", fn ->
            Selecto.select([
                "category",
                "product_name",
                "revenue",
                {:row_number, over: "PARTITION BY category ORDER BY revenue DESC", as: "rank"}
              ])
            |> Selecto.from("products")
          end)
        |> Selecto.select(["category", "product_name", "revenue", "rank"])
        |> Selecto.from("ranked_products")
        |> Selecto.filter([{"rank", {:<=, 3}}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "WITH ranked_products AS"
      assert sql =~ "ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank"
      assert sql =~ "FROM ranked_products"
      assert sql =~ "WHERE rank <= $"
      assert 3 in params
    end
    
    test "gaps and islands detection" do
      selecto = configure_test_selecto("events")
      
      result = 
        selecto
        |> Selecto.select([
            "event_date",
            "event_type",
            {:row_number, over: "ORDER BY event_date", as: "row_num"},
            {"event_date - INTERVAL '1 day' * ROW_NUMBER() OVER (ORDER BY event_date) AS group_id"}
          ])
        |> Selecto.filter([{"event_type", "active"}])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "event_date"
      assert sql =~ "event_type"
      assert sql =~ "ROW_NUMBER() OVER (ORDER BY event_date) AS row_num"
      assert sql =~ "event_date - INTERVAL '1 day' * ROW_NUMBER() OVER (ORDER BY event_date) AS group_id"
      assert sql =~ "event_type = $"
      assert "active" in params
    end
  end
  
  describe "Complex Analytics Patterns" do
    test "cohort analysis with window functions" do
      selecto = configure_test_selecto("customers")
      
      result = 
        selecto
        |> Selecto.select([
            "DATE_TRUNC('month', signup_date) AS cohort_month",
            "DATE_TRUNC('month', order_date) AS order_month",
            {:count, "DISTINCT customer_id", as: "customers"},
            {:first_value, "COUNT(DISTINCT customer_id)",
              over: "PARTITION BY DATE_TRUNC('month', signup_date) ORDER BY DATE_TRUNC('month', order_date)",
              as: "cohort_size"},
            {"COUNT(DISTINCT customer_id)::FLOAT / 
              FIRST_VALUE(COUNT(DISTINCT customer_id)) OVER 
              (PARTITION BY DATE_TRUNC('month', signup_date) ORDER BY DATE_TRUNC('month', order_date)) * 100 
              AS retention_rate"}
          ])
        |> Selecto.from("customer_orders")
        |> Selecto.group_by(["DATE_TRUNC('month', signup_date)", "DATE_TRUNC('month', order_date)"])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "DATE_TRUNC('month', signup_date) AS cohort_month"
      assert sql =~ "DATE_TRUNC('month', order_date) AS order_month"
      assert sql =~ "COUNT(DISTINCT customer_id)"
      assert sql =~ "FIRST_VALUE"
      assert sql =~ "retention_rate"
      assert sql =~ "GROUP BY DATE_TRUNC('month', signup_date), DATE_TRUNC('month', order_date)"
    end
    
    test "funnel analysis with window functions" do
      selecto = configure_test_selecto("events")
      
      result = 
        selecto
        |> Selecto.with_cte("funnel_steps", fn ->
            Selecto.select([
                "user_id",
                "event_name",
                "event_time",
                {:row_number, over: "PARTITION BY user_id ORDER BY event_time", as: "step_number"}
              ])
            |> Selecto.from("events")
            |> Selecto.filter([{"event_name", {:in, ["signup", "activation", "first_purchase", "retention"]}}])
          end)
        |> Selecto.select([
            "event_name",
            {:count, "DISTINCT user_id", as: "users_reached"},
            {:lag, "COUNT(DISTINCT user_id)", 1, over: "ORDER BY MIN(step_number)", as: "prev_step_users"},
            {"COUNT(DISTINCT user_id)::FLOAT / LAG(COUNT(DISTINCT user_id), 1) OVER (ORDER BY MIN(step_number)) * 100 AS conversion_rate"}
          ])
        |> Selecto.from("funnel_steps")
        |> Selecto.group_by(["event_name"])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "WITH funnel_steps AS"
      assert sql =~ "ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_time) AS step_number"
      assert sql =~ "event_name IN"
      assert sql =~ "COUNT(DISTINCT user_id) AS users_reached"
      assert sql =~ "LAG(COUNT(DISTINCT user_id), $) OVER (ORDER BY MIN(step_number)) AS prev_step_users"
      assert sql =~ "conversion_rate"
      assert ["signup", "activation", "first_purchase", "retention"] in params
      assert 1 in params
    end
  end
  
  describe "Performance Optimization" do
    test "using window functions instead of self-joins" do
      selecto = configure_test_selecto("metrics")
      
      # Efficient window function approach instead of self-join
      result = 
        selecto
        |> Selecto.select([
            "date",
            "metric_value",
            {:avg, "metric_value", over: "ORDER BY date ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING", as: "smoothed_value"},
            {:stddev, "metric_value", over: "ORDER BY date ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING", as: "local_stddev"}
          ])
        |> Selecto.filter([
            {"ABS(metric_value - AVG(metric_value) OVER (ORDER BY date ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING))", 
              {:>, "2 * STDDEV(metric_value) OVER (ORDER BY date ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING)"}}
          ])
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "date"
      assert sql =~ "metric_value"
      assert sql =~ "AVG(metric_value) OVER (ORDER BY date ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING) AS smoothed_value"
      assert sql =~ "STDDEV(metric_value) OVER (ORDER BY date ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING) AS local_stddev"
      assert sql =~ "ABS(metric_value"
    end
    
    test "partitioned ranking for large datasets" do
      selecto = configure_test_selecto("orders")
      
      result = 
        selecto
        |> Selecto.select([
            "region",
            "customer_id",
            "total_spent",
            {:dense_rank, over: "PARTITION BY region ORDER BY total_spent DESC", as: "regional_rank"}
          ])
        |> Selecto.filter([
            {"DENSE_RANK() OVER (PARTITION BY region ORDER BY total_spent DESC)", {:<=, 100}}
          ])
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "region"
      assert sql =~ "customer_id"
      assert sql =~ "total_spent"
      assert sql =~ "DENSE_RANK() OVER (PARTITION BY region ORDER BY total_spent DESC) AS regional_rank"
      assert sql =~ "DENSE_RANK() OVER (PARTITION BY region ORDER BY total_spent DESC) <= $"
      assert 100 in params
    end
  end
end