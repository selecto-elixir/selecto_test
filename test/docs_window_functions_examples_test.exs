defmodule DocsWindowFunctionsExamplesTest do
  use ExUnit.Case, async: true

@moduledoc """
Tests for window functions in Selecto.

Window functions are added using Selecto.window_function/4 and then included
in the SELECT clause when the query is built.
"""

  
  alias Selecto.Builder.Sql
  
  # Helper to configure test Selecto instance
  # Creates a mock domain for documentation examples that don't run against real DB
  defp configure_test_selecto(table \\ "employee") do
    # Helper to create a mock schema with required fields
    create_mock_schema = fn table_name, fields_list ->
      field_columns = fields_list
        |> Enum.map(fn field ->
          type = case field do
            f when f in [:id] -> :integer
            f when f in [:name, :first_name, :last_name, :department, :category, :event_type, 
                         :event_name, :page_view, :symbol, :region, :player] -> :string
            f when f in [:salary, :amount, :price, :lifetime_value, :total_spent, 
                         :budget, :metric_value, :revenue, :score, :volume] -> :decimal
            f when f in [:date, :hire_date, :order_date, :signup_date, :game_date, 
                         :event_date, :event_time, :timestamp] -> :datetime
            f when f in [:month, :year, :customer_id, :product_id, :user_id] -> :integer
            f when f in [:grade_level, :segment] -> :string
            _ -> :string
          end
          {field, %{type: type, name: Atom.to_string(field)}}
        end)
        |> Enum.into(%{})
      
      %{
        source_table: table_name,
        primary_key: :id,
        fields: fields_list,
        columns: field_columns,
        redact_fields: []
      }
    end
    
    # Create a mock schema structure for each entity type
    # These are simplified structures just for testing window function SQL generation
    mock_schemas = %{
      "employee" => create_mock_schema.("employees", [:id, :name, :salary, :department, :hire_date]),
      "employees" => create_mock_schema.("employees", [:id, :name, :salary, :department, :hire_date]),
      "sale" => create_mock_schema.("sales", [:id, :product_id, :customer_id, :amount, :date]),
      "sales" => create_mock_schema.("sales", [:id, :month, :revenue, :product_id, :customer_id, :amount, :date]),
      "product" => create_mock_schema.("products", [:id, :name, :category, :price]),
      "products" => create_mock_schema.("products", [:id, :product_name, :category, :price, :revenue]),
      "student" => create_mock_schema.("students", [:id, :name, :score, :grade_level]),
      "students" => create_mock_schema.("students", [:id, :name, :score, :grade_level]),
      "customer" => create_mock_schema.("customers", [:id, :name, :lifetime_value, :segment]),
      "customers" => create_mock_schema.("customers", [:id, :customer_id, :name, :lifetime_value, :segment, :signup_date, :order_date]),
      "transaction" => create_mock_schema.("transactions", [:id, :date, :amount, :type]),
      "transactions" => create_mock_schema.("transactions", [:id, :date, :amount, :type]),
      "stock_prices" => create_mock_schema.("stock_prices", [:id, :symbol, :date, :price, :volume]),
      "orders" => create_mock_schema.("orders", [:id, :customer_id, :order_date, :total_spent, :region]),
      "game_scores" => create_mock_schema.("game_scores", [:id, :player, :score, :game_date]),
      "website_sessions" => create_mock_schema.("website_sessions", [:id, :user_id, :event_time, :page_view]),
      "departments" => create_mock_schema.("departments", [:id, :name, :budget]),
      "events" => create_mock_schema.("events", [:id, :event_date, :event_type, :event_name, :event_time, :timestamp, :value, :user_id]),
      "metrics" => create_mock_schema.("metrics", [:id, :date, :metric_value]),
      "regions" => create_mock_schema.("regions", [:id, :name]),
      "revenue" => create_mock_schema.("revenue", [:id, :year, :month, :revenue]),
      "monthly_revenue" => create_mock_schema.("monthly_revenue", [:id, :month, :revenue]),
      "customer_orders" => create_mock_schema.("customer_orders", [:id, :customer_id, :signup_date, :order_date])
    }
    
    # Get the appropriate mock schema
    source_schema = mock_schemas[table] || mock_schemas["employee"]
    
    domain_config = %{
      source: source_schema,
      schemas: mock_schemas,
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
        |> Selecto.select(["name", "salary", "department"])
        |> Selecto.window_function(:avg, ["salary"], 
            over: [partition_by: ["department"]], 
            as: "dept_avg_salary")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "name"
      assert sql =~ "salary"
      assert sql =~ "department"
      # Window functions are added after regular select fields
      assert sql =~ ~r/AVG\(.*salary.*\)\s+OVER\s+\(\s*PARTITION\s+BY.*department/i
    end
    
    test "window function with ordering" do
      selecto = configure_test_selecto("sale")
      
      result = 
        selecto
        |> Selecto.select(["date", "amount"])
        |> Selecto.window_function(:sum, ["amount"], 
            over: [order_by: ["date"]], 
            as: "running_total")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "date"
      assert sql =~ "amount"
      assert sql =~ ~r/SUM\(.*amount.*\)\s+OVER\s+\(\s*ORDER\s+BY.*date/i
    end
  end
  
  describe "Ranking Functions" do
    test "ROW_NUMBER with partition and order" do
      selecto = configure_test_selecto("product")
      
      result = 
        selecto
        |> Selecto.select(["name", "category", "price"])
        |> Selecto.window_function(:row_number, [], 
            over: [
              partition_by: ["category"], 
              order_by: [{"price", :desc}]
            ], 
            as: "price_rank_in_category")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "name"
      assert sql =~ "category"
      assert sql =~ "price"
      assert sql =~ ~r/ROW_NUMBER\(\)\s+OVER\s+\(.*PARTITION\s+BY.*category.*ORDER\s+BY.*price.*DESC/i
    end
    
    test "RANK and DENSE_RANK comparison" do
      selecto = configure_test_selecto("student")
      
      result = 
        selecto
        |> Selecto.select(["name", "score"])
        |> Selecto.window_function(:rank, [], 
            over: [order_by: [{"score", :desc}]], 
            as: "rank")
        |> Selecto.window_function(:dense_rank, [], 
            over: [order_by: [{"score", :desc}]], 
            as: "dense_rank")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "name"
      assert sql =~ "score"
      assert sql =~ ~r/RANK\(\)\s+OVER\s+\(.*ORDER\s+BY.*score.*DESC/i
      assert sql =~ ~r/DENSE_RANK\(\)\s+OVER\s+\(.*ORDER\s+BY.*score.*DESC/i
    end
    
    test "percentile ranking functions" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["name", "salary"])
        |> Selecto.window_function(:percent_rank, [], 
            over: [order_by: ["salary"]], 
            as: "salary_percentile")
        |> Selecto.window_function(:cume_dist, [], 
            over: [order_by: ["salary"]], 
            as: "cumulative_distribution")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "name"
      assert sql =~ "salary"
      assert sql =~ ~r/PERCENT_RANK\(\)\s+OVER\s+\(.*ORDER\s+BY.*salary/i
      assert sql =~ ~r/CUME_DIST\(\)\s+OVER\s+\(.*ORDER\s+BY.*salary/i
    end
    
    test "NTILE for quartiles" do
      selecto = configure_test_selecto("customer")
      
      result = 
        selecto
        |> Selecto.select(["name", "total_spent"])
        |> Selecto.window_function(:ntile, [4], 
            over: [order_by: [{"total_spent", :desc}]], 
            as: "spending_quartile")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "name"
      assert sql =~ "total_spent"
      assert sql =~ ~r/NTILE\(.*\)\s+OVER\s+\(.*ORDER\s+BY.*total_spent.*DESC/i
      assert 4 in params
    end
    
    test "NTILE with multiple window functions" do
      selecto = configure_test_selecto("product")
      
      result = 
        selecto
        |> Selecto.select(["name", "revenue"])
        |> Selecto.window_function(:ntile, [10], 
            over: [order_by: [{"revenue", :desc}]], 
            as: "revenue_decile")
        |> Selecto.window_function(:ntile, [5], 
            over: [order_by: [{"revenue", :desc}]], 
            as: "revenue_quintile")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "name"
      assert sql =~ "revenue"
      assert sql =~ ~r/NTILE\(.*\)\s+OVER\s+\(.*ORDER\s+BY.*revenue.*DESC/i
      assert 10 in params
      assert 5 in params
    end
  end
  
  describe "Aggregate Window Functions" do
    test "running aggregates" do
      selecto = configure_test_selecto("transaction")
      
      result = 
        selecto
        |> Selecto.select(["date", "amount"])
        |> Selecto.window_function(:sum, ["amount"], 
            over: [order_by: ["date"]], as: "running_sum")
        |> Selecto.window_function(:avg, ["amount"], 
            over: [order_by: ["date"]], as: "running_avg")
        |> Selecto.window_function(:count, ["*"], 
            over: [order_by: ["date"]], as: "running_count")
        |> Selecto.window_function(:max, ["amount"], 
            over: [order_by: ["date"]], as: "running_max")
        |> Selecto.window_function(:min, ["amount"], 
            over: [order_by: ["date"]], as: "running_min")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "date"
      assert sql =~ "amount"
      assert sql =~ ~r/SUM\(.*amount.*\)\s+OVER\s+\(.*ORDER\s+BY.*date/i
      assert sql =~ ~r/AVG\(.*amount.*\)\s+OVER\s+\(.*ORDER\s+BY.*date/i
      assert sql =~ ~r/COUNT\(.*\*.*\)\s+OVER\s+\(.*ORDER\s+BY.*date/i
      assert sql =~ ~r/MAX\(.*amount.*\)\s+OVER\s+\(.*ORDER\s+BY.*date/i
      assert sql =~ ~r/MIN\(.*amount.*\)\s+OVER\s+\(.*ORDER\s+BY.*date/i
    end
    
    test "moving averages with frame specification" do
      selecto = configure_test_selecto("stock_prices")
      
      result = 
        selecto
        |> Selecto.select(["symbol", "date", "close_price"])
        |> Selecto.window_function(:avg, ["close_price"], 
            over: [
              partition_by: ["symbol"],
              order_by: ["date"],
              frame: {:rows, {:preceding, 6}, :current_row}
            ],
            as: "moving_avg_7_day")
        |> Selecto.window_function(:avg, ["close_price"],
            over: [
              partition_by: ["symbol"],
              order_by: ["date"],
              frame: {:rows, {:preceding, 29}, :current_row}
            ],
            as: "moving_avg_30_day")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "symbol"
      assert sql =~ "date"
      assert sql =~ "close_price"
      assert sql =~ ~r/AVG\(.*close_price.*\)\s+OVER/i
      assert sql =~ ~r/ROWS\s+BETWEEN\s+6\s+PRECEDING\s+AND\s+CURRENT\s+ROW/i
      assert sql =~ ~r/ROWS\s+BETWEEN\s+29\s+PRECEDING\s+AND\s+CURRENT\s+ROW/i
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
            {"revenue - LAG(revenue, 1) OVER (ORDER BY month) AS month_over_month_change"},
            {"(revenue - LAG(revenue, 1) OVER (ORDER BY month)) / LAG(revenue, 1) OVER (ORDER BY month) * 100 AS growth_rate"}
          ])
        |> Selecto.window_function(:lag, ["revenue", 1], 
            over: [order_by: ["month"]], 
            as: "prev_month_revenue")
        |> Selecto.window_function(:lead, ["revenue", 1], 
            over: [order_by: ["month"]], 
            as: "next_month_revenue")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "month"
      assert sql =~ "revenue"
      assert sql =~ "LAG\\(.*revenue.*\\) OVER \\(ORDER BY.*month.*\\) AS prev_month_revenue"
      assert sql =~ "LEAD\\(.*revenue.*\\) OVER \\(ORDER BY.*month.*\\) AS next_month_revenue"
      assert sql =~ "revenue - LAG\\(revenue, 1\\) OVER \\(ORDER BY month\\) AS month_over_month_change"
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
            "salary"
          ])
        |> Selecto.window_function(:first_value, ["name"], 
            over: [partition_by: ["department"], order_by: [{"salary", :desc}]],
            as: "highest_paid_in_dept")
        |> Selecto.window_function(:last_value, ["name"],
            over: [
              partition_by: ["department"], 
              order_by: [{"salary", :desc}],
              frame: {:range, :unbounded_preceding, :unbounded_following}
            ],
            as: "lowest_paid_in_dept")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "department"
      assert sql =~ "name"
      assert sql =~ "salary"
      assert sql =~ "FIRST_VALUE\\(.*name.*\\) OVER \\(PARTITION BY.*department.*ORDER BY.*salary.*DESC.*\\) AS highest_paid_in_dept"
      assert sql =~ "LAST_VALUE\\(.*name.*\\) OVER \\(PARTITION BY.*department.*ORDER BY.*salary.*DESC.*RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING.*\\) AS lowest_paid_in_dept"
    end
    
    test "NTH_VALUE function" do
      selecto = configure_test_selecto("game_scores")
      
      result = 
        selecto
        |> Selecto.select([
            "player",
            "score",
            "game_date"
          ])
        |> Selecto.window_function(:nth_value, ["score", 2],
            over: [partition_by: ["player"], order_by: [{"score", :desc}]],
            as: "second_best_score")
        |> Selecto.window_function(:nth_value, ["score", 3],
            over: [partition_by: ["player"], order_by: [{"score", :desc}]],
            as: "third_best_score")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "player"
      assert sql =~ "score"
      assert sql =~ "game_date"
      assert sql =~ "NTH_VALUE\\(.*score.*\\) OVER \\(PARTITION BY.*player.*ORDER BY.*score.*DESC.*\\) AS second_best_score"
      assert sql =~ "NTH_VALUE\\(.*score.*\\) OVER \\(PARTITION BY.*player.*ORDER BY.*score.*DESC.*\\) AS third_best_score"
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
            "amount"
          ])
        |> Selecto.window_function(:sum, ["amount"],
            over: [
              order_by: ["date"],
              frame: {:rows, {:preceding, 2}, {:following, 2}}
            ],
            as: "centered_sum_5")
        |> Selecto.window_function(:avg, ["amount"],
            over: [
              order_by: ["date"],
              frame: {:rows, :unbounded_preceding, :current_row}
            ],
            as: "cumulative_avg")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "date"
      assert sql =~ "amount"
      assert sql =~ "SUM\\(.*amount.*\\) OVER \\(.*ORDER BY.*date.*ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING.*\\) AS centered_sum_5"
      assert sql =~ "AVG\\(.*amount.*\\) OVER \\(.*ORDER BY.*date.*ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW.*\\) AS cumulative_avg"
    end
    
    test "RANGE frame specification" do
      selecto = configure_test_selecto("events")
      
      result = 
        selecto
        |> Selecto.select([
            "timestamp",
            "value"
          ])
        |> Selecto.window_function(:sum, ["value"],
            over: [
              order_by: ["timestamp"],
              frame: {:range, {:interval, "1 hour"}, :current_row}
            ],
            as: "hourly_sum")
        |> Selecto.window_function(:count, ["*"],
            over: [
              order_by: ["timestamp"],
              frame: {:range, {:interval, "24 hours"}, {:interval, "24 hours"}}
            ],
            as: "daily_count")
      
      {sql, _aliases, _params} = Sql.build(result, [])
      
      assert sql =~ "timestamp"
      assert sql =~ "value"
      assert sql =~ "SUM\\(.*value.*\\) OVER \\(.*ORDER BY.*timestamp.*RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW.*\\) AS hourly_sum"
      assert sql =~ "COUNT\\(.*\\*.*\\) OVER \\(.*ORDER BY.*timestamp.*RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND INTERVAL '24 hours' FOLLOWING.*\\) AS daily_count"
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
            {"(revenue - LAG(revenue, 12) OVER (ORDER BY year, month)) / LAG(revenue, 12) OVER (ORDER BY year, month) * 100 AS yoy_growth"}
          ])
        |> Selecto.window_function(:lag, ["revenue", 12], 
            over: [order_by: ["year", "month"]], 
            as: "revenue_last_year")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "year"
      assert sql =~ "month"
      assert sql =~ "revenue"
      assert sql =~ "LAG\\(.*revenue.*\\) OVER \\(.*ORDER BY.*year.*month.*\\) AS revenue_last_year"
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
            {"CASE WHEN event_time - LAG(event_time, 1) OVER (PARTITION BY user_id ORDER BY event_time) > INTERVAL '30 minutes' 
              THEN 1 ELSE 0 END AS new_session_flag"}
          ])
        |> Selecto.window_function(:lag, ["event_time", 1], 
            over: [partition_by: ["user_id"], order_by: ["event_time"]], 
            as: "prev_event_time")
        |> Selecto.window_function(:sum, 
            ["CASE WHEN event_time - LAG(event_time, 1) OVER (PARTITION BY user_id ORDER BY event_time) > INTERVAL '30 minutes' 
              THEN 1 ELSE 0 END"], 
            over: [partition_by: ["user_id"], order_by: ["event_time"]], 
            as: "session_id")
      
      {sql, _aliases, params} = Sql.build(result, [])
      
      assert sql =~ "user_id"
      assert sql =~ "event_time"
      assert sql =~ "page_view"
      assert sql =~ "LAG\\(.*event_time.*\\) OVER \\(PARTITION BY.*user_id.*ORDER BY.*event_time.*\\) AS prev_event_time"
      assert sql =~ "INTERVAL '30 minutes'"
      assert sql =~ "new_session_flag"
      assert sql =~ "session_id"
      assert 1 in params
    end
    
    test "top N per group" do
      selecto = configure_test_selecto("products")
      
      # Create inner query for CTE
      inner = configure_test_selecto("products")
        |> Selecto.select([
            "category",
            "product_name",
            "revenue"
          ])
        |> Selecto.window_function(:row_number, [], 
            over: [partition_by: ["category"], order_by: [{"revenue", :desc}]], 
            as: "rank")
      
      result = 
        selecto
        |> Selecto.with_cte("ranked_products", fn -> inner end)
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
            {"event_date - INTERVAL '1 day' * ROW_NUMBER() OVER (ORDER BY event_date) AS group_id"}
          ])
        |> Selecto.window_function(:row_number, [], 
            over: [order_by: ["event_date"]], 
            as: "row_num")
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
            {"COUNT(DISTINCT customer_id)::FLOAT / 
              FIRST_VALUE(COUNT(DISTINCT customer_id)) OVER 
              (PARTITION BY DATE_TRUNC('month', signup_date) ORDER BY DATE_TRUNC('month', order_date)) * 100 
              AS retention_rate"}
          ])
        |> Selecto.window_function(:first_value, ["COUNT(DISTINCT customer_id)"],
            over: [
              partition_by: ["DATE_TRUNC('month', signup_date)"],
              order_by: ["DATE_TRUNC('month', order_date)"]
            ],
            as: "cohort_size")
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
      
      # Create inner query for CTE
      inner = configure_test_selecto("events")
        |> Selecto.select([
            "user_id",
            "event_name",
            "event_time"
          ])
        |> Selecto.window_function(:row_number, [], 
            over: [partition_by: ["user_id"], order_by: ["event_time"]], 
            as: "step_number")
        |> Selecto.from("events")
        |> Selecto.filter([{"event_name", {:in, ["signup", "activation", "first_purchase", "retention"]}}])
      
      result = 
        selecto
        |> Selecto.with_cte("funnel_steps", fn -> inner end)
        |> Selecto.select([
            "event_name",
            {:count, "DISTINCT user_id", as: "users_reached"},
            {"COUNT(DISTINCT user_id)::FLOAT / LAG(COUNT(DISTINCT user_id), 1) OVER (ORDER BY MIN(step_number)) * 100 AS conversion_rate"}
          ])
        |> Selecto.window_function(:lag, ["COUNT(DISTINCT user_id)", 1], 
            over: [order_by: ["MIN(step_number)"]], 
            as: "prev_step_users")
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
            "metric_value"
          ])
        |> Selecto.window_function(:avg, ["metric_value"], 
            over: [
              order_by: ["date"],
              frame: {:rows, {:preceding, 3}, {:following, 3}}
            ], 
            as: "smoothed_value")
        |> Selecto.window_function(:stddev, ["metric_value"], 
            over: [
              order_by: ["date"],
              frame: {:rows, {:preceding, 3}, {:following, 3}}
            ], 
            as: "local_stddev")
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
            "total_spent"
          ])
        |> Selecto.window_function(:dense_rank, [], 
            over: [
              partition_by: ["region"],
              order_by: [{"total_spent", :desc}]
            ], 
            as: "regional_rank")
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