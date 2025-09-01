# Common Table Expressions (CTEs) Guide

## Overview

Common Table Expressions (CTEs) provide a powerful way to write modular, readable SQL queries. Selecto supports both non-recursive and recursive CTEs, enabling complex hierarchical queries, data transformations, and query organization. CTEs act as named temporary result sets that exist within the scope of a single SQL statement.

## Table of Contents

1. [Basic CTEs](#basic-ctes)
2. [Multiple CTEs](#multiple-ctes)
3. [Recursive CTEs](#recursive-ctes)
4. [CTE Dependencies](#cte-dependencies)
5. [Advanced Patterns](#advanced-patterns)
6. [Performance Considerations](#performance-considerations)
7. [Best Practices](#best-practices)

## Basic CTEs

### Simple CTE Definition

CTEs are defined using the `with_cte` function and can be referenced in the main query.

```elixir
# Basic CTE for data filtering
selecto
|> Selecto.with_cte("active_customers", fn ->
    Selecto.configure(customer_domain, connection)
    |> Selecto.select(["customer_id", "first_name", "last_name", "email"])
    |> Selecto.filter([{"active", true}])
    |> Selecto.filter([{"created_at", {:>, "2023-01-01"}}])
  end)
|> Selecto.select(["active_customers.*"])
|> Selecto.from("active_customers")

# CTE with aggregation
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
```

**Generated SQL:**
```sql
-- Basic CTE
WITH active_customers AS (
  SELECT customer_id, first_name, last_name, email
  FROM customer
  WHERE active = true 
    AND created_at > '2023-01-01'
)
SELECT active_customers.*
FROM active_customers;

-- CTE with aggregation
WITH customer_stats AS (
  SELECT customer_id,
         SUM(amount) AS total_spent,
         COUNT(*) AS payment_count,
         AVG(amount) AS avg_payment
  FROM payment
  GROUP BY customer_id
  HAVING SUM(amount) > 1000
)
SELECT customer.name, stats.total_spent, stats.payment_count
FROM customer
INNER JOIN customer_stats AS stats 
  ON customer.customer_id = stats.customer_id;
```

### CTEs with Complex Queries

```elixir
# CTE with joins and subqueries
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
```

## Multiple CTEs

### Defining Multiple CTEs

You can define multiple CTEs that can reference each other.

```elixir
# Multiple independent CTEs
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
```

### CTEs Referencing Other CTEs

```elixir
# Dependent CTEs
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
```

## Recursive CTEs

### Basic Recursive CTE

Recursive CTEs are perfect for hierarchical data like organizational charts, category trees, or graph traversal.

```elixir
# Employee hierarchy
selecto
|> Selecto.with_recursive_cte("org_chart",
    # Base case: top-level employees
    base_query: fn ->
      Selecto.configure(employee_domain, connection)
      |> Selecto.select([
          "employee_id",
          "name",
          "manager_id",
          {:literal, 0, as: "level"},
          {:cast, "name", :text, as: "path"}
        ])
      |> Selecto.filter([{"manager_id", nil}])
    end,
    
    # Recursive case: employees under managers
    recursive_query: fn cte_name ->
      Selecto.configure(employee_domain, connection)
      |> Selecto.select([
          "e.employee_id",
          "e.name",
          "e.manager_id",
          {:expr, "#{cte_name}.level + 1", as: "level"},
          {:concat, ["#{cte_name}.path", "' > '", "e.name"], as: "path"}
        ])
      |> Selecto.from("employee AS e")
      |> Selecto.join(:inner, cte_name, 
          on: "e.manager_id = #{cte_name}.employee_id")
    end
  )
|> Selecto.select(["*"])
|> Selecto.from("org_chart")
|> Selecto.order_by([{"level", :asc}, {"name", :asc}])
```

**Generated SQL:**
```sql
WITH RECURSIVE org_chart AS (
  -- Base case
  SELECT employee_id, name, manager_id, 
         0 AS level,
         CAST(name AS TEXT) AS path
  FROM employee
  WHERE manager_id IS NULL
  
  UNION ALL
  
  -- Recursive case
  SELECT e.employee_id, e.name, e.manager_id,
         org_chart.level + 1 AS level,
         org_chart.path || ' > ' || e.name AS path
  FROM employee AS e
  INNER JOIN org_chart ON e.manager_id = org_chart.employee_id
)
SELECT *
FROM org_chart
ORDER BY level ASC, name ASC;
```

### Category Tree Traversal

```elixir
# Find all subcategories
selecto
|> Selecto.with_recursive_cte("category_tree",
    base_query: fn ->
      Selecto.configure(category_domain, connection)
      |> Selecto.select(["category_id", "name", "parent_id"])
      |> Selecto.filter([{"category_id", root_category_id}])
    end,
    
    recursive_query: fn cte ->
      Selecto.configure(category_domain, connection)
      |> Selecto.select(["c.category_id", "c.name", "c.parent_id"])
      |> Selecto.from("category AS c")
      |> Selecto.join(:inner, cte, on: "c.parent_id = #{cte}.category_id")
    end
  )
|> Selecto.select([
    "category_id",
    "name",
    {:count, "product.product_id", as: "product_count"}
  ])
|> Selecto.from("category_tree")
|> Selecto.join(:left, "product", on: "category_tree.category_id = product.category_id")
|> Selecto.group_by(["category_tree.category_id", "category_tree.name"])
```

### Graph Traversal

```elixir
# Find all connected nodes in a graph
selecto
|> Selecto.with_recursive_cte("connected_nodes",
    base_query: fn ->
      Selecto.configure(graph_domain, connection)
      |> Selecto.select([
          {:literal, start_node, as: "node_id"},
          {:literal, 0, as: "distance"},
          {:array, [start_node], as: "path"},
          {:literal, false, as: "is_cycle"}
        ])
    end,
    
    recursive_query: fn cte ->
      Selecto.configure(edge_domain, connection)
      |> Selecto.select([
          {:case_when, [
            {["e.source_id = cn.node_id"], "e.target_id"},
            {["e.target_id = cn.node_id"], "e.source_id"}
          ], as: "node_id"},
          "cn.distance + 1 AS distance",
          {:array_append, "cn.path", "node_id", as: "path"},
          {:array_contains, "cn.path", "node_id", as: "is_cycle"}
        ])
      |> Selecto.from("edge AS e")
      |> Selecto.join(:inner, "connected_nodes AS cn", 
          on: "(e.source_id = cn.node_id OR e.target_id = cn.node_id)")
      |> Selecto.filter([{"cn.is_cycle", false}])
      |> Selecto.filter([{"cn.distance", {:<, max_depth}}])
    end
  )
|> Selecto.select(["DISTINCT node_id", "MIN(distance) AS min_distance"])
|> Selecto.from("connected_nodes")
|> Selecto.group_by(["node_id"])
|> Selecto.order_by([{"min_distance", :asc}])
```

## CTE Dependencies

### Managing CTE Order

CTEs can depend on each other and Selecto handles the dependency ordering.

```elixir
# Complex dependency chain
selecto
|> Selecto.with_ctes([
    # First CTE: base data
    {"raw_sales", fn ->
      Selecto.configure(sales_domain, connection)
      |> Selecto.select(["*"])
      |> Selecto.filter([{"year", 2024}])
    end},
    
    # Second CTE: depends on raw_sales
    {"monthly_sales", fn ->
      Selecto.from("raw_sales")
      |> Selecto.select([
          {:date_trunc, "month", "sale_date", as: "month"},
          {:sum, "amount", as: "total"}
        ])
      |> Selecto.group_by(["month"])
    end},
    
    # Third CTE: depends on monthly_sales
    {"quarterly_sales", fn ->
      Selecto.from("monthly_sales")
      |> Selecto.select([
          {:date_trunc, "quarter", "month", as: "quarter"},
          {:sum, "total", as: "quarterly_total"}
        ])
      |> Selecto.group_by(["quarter"])
    end},
    
    # Fourth CTE: depends on both monthly and quarterly
    {"comparison", fn ->
      Selecto.from("monthly_sales AS m")
      |> Selecto.select([
          "m.month",
          "m.total AS monthly_total",
          "q.quarterly_total",
          "m.total / q.quarterly_total * 100 AS percent_of_quarter"
        ])
      |> Selecto.join(:inner, "quarterly_sales AS q",
          on: "DATE_TRUNC('quarter', m.month) = q.quarter")
    end}
  ])
|> Selecto.select(["*"])
|> Selecto.from("comparison")
|> Selecto.order_by([{"month", :asc}])
```

## Advanced Patterns

### Data Transformation Pipeline

```elixir
# Multi-stage data transformation
selecto
|> Selecto.with_cte("stage1_extract", fn ->
    # Extract and parse JSON data
    Selecto.configure(raw_data_domain, connection)
    |> Selecto.select([
        "id",
        {:json_get_text, "data", "customer_id", as: "customer_id"},
        {:json_get_text, "data", "product_id", as: "product_id"},
        {:cast, {:json_get_text, "data", "amount"}, :decimal, as: "amount"},
        {:cast, {:json_get_text, "data", "timestamp"}, :timestamp, as: "created_at"}
      ])
    |> Selecto.filter([{:json_get_text, "data", "status", "completed"}])
  end)
|> Selecto.with_cte("stage2_enrich", fn ->
    # Join with dimension tables
    Selecto.from("stage1_extract AS s1")
    |> Selecto.select([
        "s1.*",
        "c.name AS customer_name",
        "c.segment AS customer_segment",
        "p.name AS product_name",
        "p.category AS product_category"
      ])
    |> Selecto.join(:left, "customer AS c", on: "s1.customer_id = c.id")
    |> Selecto.join(:left, "product AS p", on: "s1.product_id = p.id")
  end)
|> Selecto.with_cte("stage3_aggregate", fn ->
    # Aggregate metrics
    Selecto.from("stage2_enrich")
    |> Selecto.select([
        "customer_segment",
        "product_category",
        {:count, "*", as: "transaction_count"},
        {:sum, "amount", as: "total_revenue"},
        {:avg, "amount", as: "avg_transaction"}
      ])
    |> Selecto.group_by(["customer_segment", "product_category"])
  end)
|> Selecto.select(["*"])
|> Selecto.from("stage3_aggregate")
|> Selecto.order_by([{"total_revenue", :desc}])
```

### Recursive Path Finding

```elixir
# Find shortest path between nodes
selecto
|> Selecto.with_recursive_cte("paths",
    base_query: fn ->
      Selecto.select([
          {:literal, start_node, as: "current_node"},
          {:literal, 0, as: "total_cost"},
          {:array, [start_node], as: "path"},
          {:literal, start_node == end_node, as: "reached_target"}
        ])
    end,
    
    recursive_query: fn cte ->
      Selecto.from("edge AS e")
      |> Selecto.select([
          "e.target_id AS current_node",
          "p.total_cost + e.weight AS total_cost",
          {:array_append, "p.path", "e.target_id", as: "path"},
          "e.target_id = #{end_node} AS reached_target"
        ])
      |> Selecto.join(:inner, "paths AS p", on: "e.source_id = p.current_node")
      |> Selecto.filter([
          {"p.reached_target", false},
          {:not, {:array_contains, "p.path", "e.target_id"}}
        ])
    end
  )
|> Selecto.select([
    "path",
    "total_cost"
  ])
|> Selecto.from("paths")
|> Selecto.filter([{"reached_target", true}])
|> Selecto.order_by([{"total_cost", :asc}])
|> Selecto.limit(1)
```

### Materialized vs Non-Materialized CTEs

```elixir
# Force materialization (PostgreSQL 12+)
selecto
|> Selecto.with_cte("expensive_calculation", 
    fn ->
      Selecto.configure(large_table_domain, connection)
      |> Selecto.select(["complex_function(data) AS result"])
      |> Selecto.filter([{"condition", true}])
    end,
    materialized: true  # Forces CTE to be materialized
  )
|> Selecto.select(["*"])
|> Selecto.from("expensive_calculation")

# Prevent materialization (inline the CTE)
selecto
|> Selecto.with_cte("simple_filter",
    fn ->
      Selecto.configure(table_domain, connection)
      |> Selecto.select(["*"])
      |> Selecto.filter([{"active", true}])
    end,
    materialized: false  # Inline the CTE for optimization
  )
```

## Performance Considerations

### CTE Materialization

PostgreSQL's handling of CTEs:

1. **Pre-12 behavior**: CTEs are always materialized (computed once)
2. **12+ behavior**: CTEs are inlined unless:
   - Referenced multiple times
   - Contains volatile functions
   - Explicitly marked as MATERIALIZED

```elixir
# Good: CTE referenced once, will be inlined in PG 12+
selecto
|> Selecto.with_cte("filtered_data", fn ->
    Selecto.filter([{"status", "active"}])
  end)
|> Selecto.from("filtered_data")

# Consider: CTE referenced multiple times, will be materialized
selecto
|> Selecto.with_cte("expensive_calc", fn ->
    Selecto.select(["costly_function(data) AS result"])
  end)
|> Selecto.select(["a.result", "b.result"])
|> Selecto.from("expensive_calc AS a")
|> Selecto.join(:cross, "expensive_calc AS b")
```

### Recursive CTE Optimization

```elixir
# Add termination conditions to prevent runaway recursion
selecto
|> Selecto.with_recursive_cte("hierarchy",
    base_query: fn -> ... end,
    recursive_query: fn cte ->
      query
      |> Selecto.filter([
          {"level", {:<, 10}},        # Depth limit
          {"is_cycle", false}          # Cycle detection
        ])
      |> Selecto.limit(1000)          # Row limit per iteration
    end,
    # Global recursion settings
    max_recursion: 100  # Maximum iterations
  )
```

### Index Considerations

```sql
-- Indexes for CTE joins
CREATE INDEX idx_employee_manager ON employee(manager_id);
CREATE INDEX idx_category_parent ON category(parent_id);

-- Indexes for CTE filters
CREATE INDEX idx_payment_customer_date 
  ON payment(customer_id, payment_date);
```

## Best Practices

### 1. Use CTEs for Readability

```elixir
# Good: Clear, modular query structure
selecto
|> Selecto.with_cte("valid_customers", fn -> ... end)
|> Selecto.with_cte("recent_orders", fn -> ... end)
|> Selecto.with_cte("order_totals", fn -> ... end)
|> Selecto.select(["..."])

# Avoid: Deeply nested subqueries
selecto
|> Selecto.from("(SELECT ... FROM (SELECT ... FROM ...))")
```

### 2. Avoid Unnecessary CTEs

```elixir
# Unnecessary: Simple filter doesn't need CTE
selecto
|> Selecto.with_cte("active", fn ->
    Selecto.filter([{"active", true}])
  end)

# Better: Direct filter
selecto
|> Selecto.filter([{"active", true}])
```

### 3. Name CTEs Descriptively

```elixir
# Good: Clear purpose
|> Selecto.with_cte("customers_with_recent_high_value_orders", ...)
|> Selecto.with_cte("products_low_in_stock", ...)

# Avoid: Generic names
|> Selecto.with_cte("temp1", ...)
|> Selecto.with_cte("data", ...)
```

### 4. Limit Recursive Depth

```elixir
# Always include termination conditions
recursive_query: fn cte ->
  query
  |> Selecto.filter([
      {"depth", {:<, max_depth}},
      {:not, {:array_contains, "visited", "node_id"}}
    ])
end
```

### 5. Consider Materialization Trade-offs

```elixir
# Materialize when:
# - CTE is referenced multiple times
# - CTE contains expensive calculations
# - You want to force evaluation order

# Don't materialize when:
# - CTE is a simple filter
# - You want the optimizer to inline
# - Performance testing shows inlining is faster
```

## Common Use Cases

### Hierarchical Data Navigation

```elixir
# Organization chart with reporting lines
selecto
|> Selecto.with_recursive_cte("reports_to_ceo",
    base_query: fn ->
      Selecto.filter([{"title", "CEO"}])
    end,
    recursive_query: fn cte ->
      Selecto.join(:inner, cte, on: "employee.manager_id = #{cte}.employee_id")
    end
  )
```

### Running Totals and Analytics

```elixir
# Sales analysis with running totals
selecto
|> Selecto.with_cte("daily_sales", fn -> ... end)
|> Selecto.with_cte("running_metrics", fn ->
    Selecto.from("daily_sales")
    |> Selecto.select([
        "*",
        {:sum, "revenue", over: "ORDER BY date", as: "running_total"},
        {:avg, "revenue", 
          over: "ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW",
          as: "seven_day_avg"}
      ])
  end)
```

### Data Deduplication

```elixir
# Remove duplicates using CTEs
selecto
|> Selecto.with_cte("ranked_records", fn ->
    Selecto.select([
        "*",
        {:row_number, over: "PARTITION BY email ORDER BY created_at DESC", 
          as: "rn"}
      ])
  end)
|> Selecto.select(["*"])
|> Selecto.from("ranked_records")
|> Selecto.filter([{"rn", 1}])
```

## Error Handling

### Common Errors

```elixir
# ERROR: recursive reference to query "cte_name" must not appear within a subquery
# Solution: Reference recursive CTE directly in FROM or JOIN
recursive_query: fn cte ->
  Selecto.from(cte)  # Good
  # Not: Selecto.from("(SELECT * FROM #{cte})")  # Bad
end

# ERROR: infinite recursion detected
# Solution: Add termination condition
recursive_query: fn cte ->
  query
  |> Selecto.filter([{"depth", {:<, 100}}])
end

# ERROR: circular dependency between CTEs
# Solution: Reorder CTEs or refactor dependencies
```

## PostgreSQL Version Compatibility

| Feature | Min Version | Notes |
|---------|-------------|-------|
| Basic WITH | 8.4+ | Non-recursive CTEs |
| WITH RECURSIVE | 8.4+ | Recursive CTEs |
| MATERIALIZED/NOT MATERIALIZED | 12+ | Explicit materialization control |
| SEARCH/CYCLE clauses | 14+ | Built-in recursion helpers |

## See Also

- [PostgreSQL CTE Documentation](https://www.postgresql.org/docs/current/queries-with.html)
- [LATERAL Joins Guide](./lateral-joins.md)
- [Window Functions Guide](./window-functions.md)
- [Array Operations Guide](./array-operations.md)