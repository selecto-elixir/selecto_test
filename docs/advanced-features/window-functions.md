# Window Functions Guide

## Overview

Window functions perform calculations across a set of table rows that are related to the current row, without grouping rows together like aggregate functions do. Selecto provides comprehensive support for PostgreSQL window functions, enabling sophisticated analytics, ranking, and running calculations.

## Table of Contents

1. [Understanding Window Functions](#understanding-window-functions)
2. [Ranking Functions](#ranking-functions)
3. [Aggregate Window Functions](#aggregate-window-functions)
4. [Value Functions](#value-functions)
5. [Frame Specifications](#frame-specifications)
6. [Partitioning and Ordering](#partitioning-and-ordering)
7. [Advanced Patterns](#advanced-patterns)
8. [Performance Optimization](#performance-optimization)

## Understanding Window Functions

### Basic Syntax

Window functions operate over a "window" of rows defined by the OVER clause:

```elixir
# Basic window function
selecto
|> Selecto.select([
    "employee.name",
    "employee.salary",
    "employee.department",
    {:avg, "salary", over: "PARTITION BY department", as: "dept_avg_salary"}
  ])

# With ordering
selecto
|> Selecto.select([
    "sale.date",
    "sale.amount",
    {:sum, "amount", over: "ORDER BY date", as: "running_total"}
  ])
```

**Generated SQL:**
```sql
-- Partitioned average
SELECT name, salary, department,
       AVG(salary) OVER (PARTITION BY department) AS dept_avg_salary
FROM employee;

-- Running total
SELECT date, amount,
       SUM(amount) OVER (ORDER BY date) AS running_total
FROM sale;
```

## Ranking Functions

### ROW_NUMBER, RANK, and DENSE_RANK

```elixir
# Row numbering
selecto
|> Selecto.select([
    "product.name",
    "product.category",
    "product.price",
    {:row_number, over: "PARTITION BY category ORDER BY price DESC", 
      as: "price_rank_in_category"}
  ])

# Ranking with ties
selecto
|> Selecto.select([
    "student.name",
    "student.score",
    {:rank, over: "ORDER BY score DESC", as: "rank"},
    {:dense_rank, over: "ORDER BY score DESC", as: "dense_rank"}
  ])

# Percentile ranking
selecto
|> Selecto.select([
    "employee.name",
    "employee.salary",
    {:percent_rank, over: "ORDER BY salary", as: "salary_percentile"},
    {:cume_dist, over: "ORDER BY salary", as: "cumulative_distribution"}
  ])
```

**Generated SQL:**
```sql
-- Row numbering
SELECT name, category, price,
       ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC) AS price_rank_in_category
FROM product;

-- Ranking comparison
SELECT name, score,
       RANK() OVER (ORDER BY score DESC) AS rank,
       DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rank
FROM student;

-- Percentile
SELECT name, salary,
       PERCENT_RANK() OVER (ORDER BY salary) AS salary_percentile,
       CUME_DIST() OVER (ORDER BY salary) AS cumulative_distribution
FROM employee;
```

### NTILE for Bucketing

```elixir
# Divide data into quartiles
selecto
|> Selecto.select([
    "customer.name",
    "customer.total_spent",
    {:ntile, 4, over: "ORDER BY total_spent DESC", as: "spending_quartile"}
  ])

# Create deciles for analysis
selecto
|> Selecto.select([
    "product.name",
    "product.revenue",
    {:ntile, 10, over: "ORDER BY revenue DESC", as: "revenue_decile"},
    {:case_when, [
        {[{:ntile, 10, over: "ORDER BY revenue DESC"}, {:<=, 2}], "Top 20%"},
        {[{:ntile, 10, over: "ORDER BY revenue DESC"}, {:<=, 5}], "Top 50%"},
        {[true], "Bottom 50%"}
      ], as: "performance_tier"}
  ])
```

## Aggregate Window Functions

### Running Aggregates

```elixir
# Running calculations
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

# Partitioned aggregates
selecto
|> Selecto.select([
    "sale.region",
    "sale.month",
    "sale.revenue",
    {:sum, "revenue", over: "PARTITION BY region ORDER BY month", 
      as: "ytd_revenue"},
    {:avg, "revenue", over: "PARTITION BY region", 
      as: "avg_monthly_revenue"}
  ])
```

### Statistical Functions

```elixir
# Standard deviation and variance
selecto
|> Selecto.select([
    "stock.date",
    "stock.price",
    {:stddev, "price", 
      over: "ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW",
      as: "20_day_volatility"},
    {:var_pop, "price",
      over: "ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW",
      as: "30_day_variance"}
  ])

# Correlation and covariance
selecto
|> Selecto.select([
    "portfolio.date",
    "portfolio.stock_a_return",
    "portfolio.stock_b_return",
    {:corr, ["stock_a_return", "stock_b_return"],
      over: "ORDER BY date ROWS BETWEEN 59 PRECEDING AND CURRENT ROW",
      as: "60_day_correlation"}
  ])
```

## Value Functions

### LAG and LEAD

```elixir
# Access previous and next rows
selecto
|> Selecto.select([
    "stock.date",
    "stock.close_price",
    {:lag, "close_price", 1, over: "ORDER BY date", as: "prev_close"},
    {:lead, "close_price", 1, over: "ORDER BY date", as: "next_close"},
    # Calculate daily change
    {:expr, "close_price - LAG(close_price, 1) OVER (ORDER BY date)", 
      as: "daily_change"},
    # Calculate percentage change
    {:expr, "(close_price - LAG(close_price, 1) OVER (ORDER BY date)) / LAG(close_price, 1) OVER (ORDER BY date) * 100",
      as: "daily_pct_change"}
  ])

# Multiple lag/lead with defaults
selecto
|> Selecto.select([
    "event.timestamp",
    "event.value",
    {:lag, "value", 1, default: 0, over: "ORDER BY timestamp", as: "prev_value"},
    {:lag, "value", 7, default: 0, over: "ORDER BY timestamp", as: "week_ago_value"},
    {:lead, "value", 1, default: 0, over: "ORDER BY timestamp", as: "next_value"}
  ])
```

### FIRST_VALUE and LAST_VALUE

```elixir
# Get first and last values in window
selecto
|> Selecto.select([
    "employee.name",
    "employee.department",
    "employee.hire_date",
    "employee.salary",
    {:first_value, "name", 
      over: "PARTITION BY department ORDER BY hire_date",
      as: "first_hired"},
    {:last_value, "name",
      over: "PARTITION BY department ORDER BY hire_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING",
      as: "last_hired"},
    {:first_value, "salary",
      over: "PARTITION BY department ORDER BY salary DESC",
      as: "highest_salary_in_dept"}
  ])
```

### NTH_VALUE

```elixir
# Get specific position values
selecto
|> Selecto.select([
    "race.participant",
    "race.finish_time",
    {:nth_value, "participant", 1,
      over: "ORDER BY finish_time",
      as: "gold_medalist"},
    {:nth_value, "participant", 2,
      over: "ORDER BY finish_time",
      as: "silver_medalist"},
    {:nth_value, "participant", 3,
      over: "ORDER BY finish_time",
      as: "bronze_medalist"}
  ])
```

## Frame Specifications

### Row-based Frames

```elixir
# Moving averages with different windows
selecto
|> Selecto.select([
    "metric.date",
    "metric.value",
    # 7-day moving average
    {:avg, "value",
      over: "ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW",
      as: "ma_7"},
    # 30-day moving average
    {:avg, "value",
      over: "ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW",
      as: "ma_30"},
    # Centered 5-day average
    {:avg, "value",
      over: "ORDER BY date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING",
      as: "ma_5_centered"}
  ])
```

### Range-based Frames

```elixir
# Time-based windows
selecto
|> Selecto.select([
    "sensor.timestamp",
    "sensor.reading",
    # Last hour average
    {:avg, "reading",
      over: "ORDER BY timestamp RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW",
      as: "hourly_avg"},
    # Last 24 hours max
    {:max, "reading",
      over: "ORDER BY timestamp RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND CURRENT ROW",
      as: "daily_max"}
  ])

# Value-based ranges
selecto
|> Selecto.select([
    "product.price",
    "product.units_sold",
    # Products within $10 price range
    {:avg, "units_sold",
      over: "ORDER BY price RANGE BETWEEN 10 PRECEDING AND 10 FOLLOWING",
      as: "avg_sales_similar_price"}
  ])
```

### Groups Frame

```elixir
# PostgreSQL 11+ GROUPS frame
selecto
|> Selecto.select([
    "log.timestamp",
    "log.event",
    # Last 5 distinct events
    {:count, "*",
      over: "ORDER BY timestamp GROUPS BETWEEN 4 PRECEDING AND CURRENT ROW",
      as: "recent_event_count"}
  ])
```

## Partitioning and Ordering

### Multiple Partitions

```elixir
# Complex partitioning
selecto
|> Selecto.select([
    "sale.region",
    "sale.product_category",
    "sale.salesperson",
    "sale.amount",
    {:rank, 
      over: "PARTITION BY region, product_category ORDER BY amount DESC",
      as: "rank_in_region_category"},
    {:percent_rank,
      over: "PARTITION BY salesperson ORDER BY amount DESC",
      as: "personal_sale_percentile"}
  ])
```

### Dynamic Window Specifications

```elixir
# Reusable window definitions
window_specs = %{
  by_dept: "PARTITION BY department ORDER BY salary DESC",
  by_date: "ORDER BY hire_date",
  recent: "ORDER BY hire_date ROWS BETWEEN 5 PRECEDING AND CURRENT ROW"
}

selecto
|> Selecto.select([
    "employee.*",
    {:rank, over: window_specs.by_dept, as: "salary_rank"},
    {:row_number, over: window_specs.by_date, as: "hire_order"},
    {:count, "*", over: window_specs.recent, as: "recent_hires"}
  ])
```

## Advanced Patterns

### Gap and Island Detection

```elixir
# Find consecutive sequences
selecto
|> Selecto.select([
    "event.user_id",
    "event.date",
    {:expr, "date - ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY date)",
      as: "group_id"}
  ])
|> Selecto.with_cte("grouped_events", fn -> ... end)
|> Selecto.select([
    "user_id",
    "MIN(date) AS streak_start",
    "MAX(date) AS streak_end",
    "COUNT(*) AS streak_length"
  ])
|> Selecto.from("grouped_events")
|> Selecto.group_by(["user_id", "group_id"])
```

### Pivot with Window Functions

```elixir
# Dynamic pivot using window functions
selecto
|> Selecto.select([
    "product.category",
    {:max, {:case_when, [
        {[{:row_number, over: "PARTITION BY category ORDER BY revenue DESC"}, 1],
          "product.name"}
      ]}, as: "top_product"},
    {:max, {:case_when, [
        {[{:row_number, over: "PARTITION BY category ORDER BY revenue DESC"}, 2],
          "product.name"}
      ]}, as: "second_product"},
    {:max, {:case_when, [
        {[{:row_number, over: "PARTITION BY category ORDER BY revenue DESC"}, 3],
          "product.name"}
      ]}, as: "third_product"}
  ])
|> Selecto.group_by(["category"])
```

### Year-over-Year Comparisons

```elixir
# YoY growth calculation
selecto
|> Selecto.select([
    "monthly_sales.year",
    "monthly_sales.month",
    "monthly_sales.revenue",
    {:lag, "revenue", 12, over: "ORDER BY year, month", as: "revenue_last_year"},
    {:expr, "(revenue - LAG(revenue, 12) OVER (ORDER BY year, month)) / LAG(revenue, 12) OVER (ORDER BY year, month) * 100",
      as: "yoy_growth_pct"}
  ])
```

### Sessionization

```elixir
# Identify user sessions with 30-minute timeout
selecto
|> Selecto.select([
    "activity.user_id",
    "activity.timestamp",
    {:lag, "timestamp", 1, over: "PARTITION BY user_id ORDER BY timestamp",
      as: "prev_timestamp"},
    {:case_when, [
        {[{:expr, "timestamp - LAG(timestamp, 1) OVER (PARTITION BY user_id ORDER BY timestamp) > INTERVAL '30 minutes'"}],
          1},
        {[{:expr, "LAG(timestamp, 1) OVER (PARTITION BY user_id ORDER BY timestamp) IS NULL"}],
          1}
      ], else: 0, as: "new_session"},
    {:sum, {:case_when, [...]}, 
      over: "PARTITION BY user_id ORDER BY timestamp",
      as: "session_id"}
  ])
```

## Performance Optimization

### Index Strategies

```sql
-- Indexes for window function ORDER BY
CREATE INDEX idx_employee_dept_salary ON employee(department, salary DESC);

-- Covering index for window queries
CREATE INDEX idx_sale_date_amount ON sale(date, amount) INCLUDE (customer_id);

-- Partial index for filtered windows
CREATE INDEX idx_active_employee_salary ON employee(department, salary) 
WHERE active = true;
```

### Query Optimization

```elixir
# GOOD: Minimize window function calls
selecto
|> Selecto.with_cte("windowed_data", fn ->
    Selecto.select([
        "*",
        {:row_number, over: "...", as: "rn"},
        {:sum, "amount", over: "...", as: "total"}
      ])
  end)
|> Selecto.from("windowed_data")
|> Selecto.filter([{"rn", {:<=, 10}}])

# AVOID: Multiple passes over same window
selecto
|> Selecto.select([
    {:row_number, over: "ORDER BY x", as: "rn1"},
    {:rank, over: "ORDER BY x", as: "rn2"},
    {:dense_rank, over: "ORDER BY x", as: "rn3"}
  ])

# BETTER: Use WINDOW clause (if supported)
selecto
|> Selecto.window("w", "ORDER BY x")
|> Selecto.select([
    {:row_number, over: "w", as: "rn1"},
    {:rank, over: "w", as: "rn2"},
    {:dense_rank, over: "w", as: "rn3"}
  ])
```

### Memory Considerations

```elixir
# Limit frame size for large datasets
selecto
|> Selecto.select([
    # Limited to 100 rows
    {:avg, "value", 
      over: "ORDER BY date ROWS BETWEEN 99 PRECEDING AND CURRENT ROW",
      as: "moving_avg"}
  ])

# Use range frames for time-series
selecto
|> Selecto.select([
    # More efficient for timestamp-based windows
    {:avg, "value",
      over: "ORDER BY timestamp RANGE BETWEEN INTERVAL '1 day' PRECEDING AND CURRENT ROW",
      as: "daily_avg"}
  ])
```

## Common Use Cases

### Top-N Per Group

```elixir
# Top 3 products per category
selecto
|> Selecto.with_cte("ranked_products", fn ->
    Selecto.select([
        "*",
        {:row_number, 
          over: "PARTITION BY category ORDER BY revenue DESC",
          as: "rank"}
      ])
    |> Selecto.from("products")
  end)
|> Selecto.select(["*"])
|> Selecto.from("ranked_products")
|> Selecto.filter([{"rank", {:<=, 3}}])
```

### Running Totals and Balances

```elixir
# Account balance calculation
selecto
|> Selecto.select([
    "transaction.date",
    "transaction.description",
    "transaction.amount",
    {:sum, "amount", 
      over: "PARTITION BY account_id ORDER BY date, transaction_id",
      as: "balance"}
  ])
|> Selecto.filter([{"account_id", account_id}])
|> Selecto.order_by([{"date", :desc}])
```

### Moving Averages

```elixir
# Stock price analysis
selecto
|> Selecto.select([
    "date",
    "close_price",
    {:avg, "close_price",
      over: "ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW",
      as: "sma_20"},
    {:avg, "close_price",
      over: "ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW",
      as: "sma_50"},
    {:case_when, [
        {[{:expr, "close_price > AVG(close_price) OVER (ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW)"}],
          "Above SMA20"},
        {[true], "Below SMA20"}
      ], as: "signal"}
  ])
```

## Error Handling

### Common Errors

```elixir
# ERROR: window function calls cannot be nested
# BAD: ROW_NUMBER() OVER (ORDER BY ROW_NUMBER() OVER (...))
# Solution: Use CTE or subquery
|> Selecto.with_cte("first_window", fn ->
    Selecto.select([{:row_number, over: "...", as: "rn"}])
  end)
|> Selecto.select([{:row_number, over: "ORDER BY rn", as: "final_rank"}])

# ERROR: frame end cannot be UNBOUNDED PRECEDING
# Solution: Check frame bounds
# Correct: ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
# Wrong: ROWS BETWEEN CURRENT ROW AND UNBOUNDED PRECEDING

# ERROR: DISTINCT is not implemented for window functions
# Solution: Use subquery or CTE for DISTINCT
|> Selecto.with_cte("distinct_values", fn ->
    Selecto.select(["DISTINCT category"])
  end)
```

## PostgreSQL Version Compatibility

| Feature | Min Version | Notes |
|---------|-------------|-------|
| Basic window functions | 8.4+ | ROW_NUMBER, RANK, etc. |
| RANGE frames | 9.0+ | Range-based windows |
| FILTER clause | 9.4+ | Aggregate filters |
| GROUPS frame | 11+ | Group-based frames |
| EXCLUDE clause | 11+ | Exclude rows from frame |

## Best Practices

1. **Index ORDER BY columns**: Create indexes on columns used in window ORDER BY
2. **Limit frame size**: Use bounded frames for better performance
3. **Use CTEs for complex windows**: Improve readability and reusability
4. **Consider materialized views**: For frequently used window calculations
5. **Test with EXPLAIN**: Verify execution plans for large datasets
6. **Avoid nested windows**: Use CTEs to layer window calculations

## See Also

- [PostgreSQL Window Functions](https://www.postgresql.org/docs/current/tutorial-window.html)
- [Common Table Expressions Guide](./cte.md)
- [Aggregate Functions Guide](./aggregates.md)
- [Performance Tuning Guide](./performance.md)