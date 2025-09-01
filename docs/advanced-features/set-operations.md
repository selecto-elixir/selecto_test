# Set Operations Guide

## Overview

Set operations combine results from multiple queries into a single result set. Selecto supports all standard SQL set operations: UNION, INTERSECT, and EXCEPT, along with their ALL variants. These operations are essential for data comparison, deduplication, and complex analytical queries.

## Table of Contents

1. [UNION Operations](#union-operations)
2. [INTERSECT Operations](#intersect-operations)
3. [EXCEPT Operations](#except-operations)
4. [Combining Multiple Set Operations](#combining-multiple-set-operations)
5. [Set Operations with CTEs](#set-operations-with-ctes)
6. [Advanced Patterns](#advanced-patterns)
7. [Performance Optimization](#performance-optimization)
8. [Best Practices](#best-practices)

## UNION Operations

### UNION vs UNION ALL

```elixir
# UNION - removes duplicates
selecto
|> Selecto.union(
    Selecto.configure(employees_domain, connection)
    |> Selecto.select(["name", "email", {:literal, "Employee", as: "type"}])
    |> Selecto.filter([{"active", true}])
  )
|> Selecto.union(
    Selecto.configure(contractors_domain, connection)
    |> Selecto.select(["name", "email", {:literal, "Contractor", as: "type"}])
    |> Selecto.filter([{"contract_active", true}])
  )
|> Selecto.order_by([{"name", :asc}])

# UNION ALL - keeps duplicates (faster)
selecto
|> Selecto.select(["product_id", "quantity", "order_date"])
|> Selecto.from("online_orders")
|> Selecto.union_all(
    Selecto.configure(store_orders_domain, connection)
    |> Selecto.select(["product_id", "quantity", "sale_date AS order_date"])
  )
|> Selecto.union_all(
    Selecto.configure(phone_orders_domain, connection)
    |> Selecto.select(["product_id", "quantity", "call_date AS order_date"])
  )
```

**Generated SQL:**
```sql
-- UNION (distinct)
SELECT name, email, 'Employee' AS type FROM employees WHERE active = true
UNION
SELECT name, email, 'Contractor' AS type FROM contractors WHERE contract_active = true
ORDER BY name ASC;

-- UNION ALL (all rows)
SELECT product_id, quantity, order_date FROM online_orders
UNION ALL
SELECT product_id, quantity, sale_date AS order_date FROM store_orders
UNION ALL
SELECT product_id, quantity, call_date AS order_date FROM phone_orders;
```

### Combining Different Sources

```elixir
# Merge data from multiple tables with type indicators
selecto
|> Selecto.with_set_operation(:union_all, [
    # Current year data
    {:query, fn ->
      Selecto.select([
          "customer_id",
          "order_date",
          "total",
          {:literal, 2024, as: "year"},
          {:literal, "current", as: "period"}
        ])
      |> Selecto.from("orders_2024")
    end},
    
    # Previous year data
    {:query, fn ->
      Selecto.select([
          "customer_id",
          "order_date",
          "total",
          {:literal, 2023, as: "year"},
          {:literal, "previous", as: "period"}
        ])
      |> Selecto.from("orders_2023")
    end},
    
    # Archived data
    {:query, fn ->
      Selecto.select([
          "customer_id",
          "order_date",
          "total",
          "EXTRACT(YEAR FROM order_date) AS year",
          {:literal, "archive", as: "period"}
        ])
      |> Selecto.from("orders_archive")
      |> Selecto.filter([{"order_date", {:<, "2023-01-01"}}])
    end}
  ])
|> Selecto.select([
    "year",
    "period",
    {:count, "*", as: "order_count"},
    {:sum, "total", as: "total_revenue"}
  ])
|> Selecto.group_by(["year", "period"])
```

## INTERSECT Operations

### Finding Common Records

```elixir
# Find customers who are also employees
selecto
|> Selecto.select(["email", "name"])
|> Selecto.from("customers")
|> Selecto.intersect(
    Selecto.select(["email", "name"])
    |> Selecto.from("employees")
  )

# Products available in all stores (using INTERSECT ALL)
selecto
|> Selecto.select(["product_id"])
|> Selecto.from("store_inventory")
|> Selecto.filter([{"store_id", 1}])
|> Selecto.intersect_all(
    Selecto.select(["product_id"])
    |> Selecto.from("store_inventory")
    |> Selecto.filter([{"store_id", 2}])
  )
|> Selecto.intersect_all(
    Selecto.select(["product_id"])
    |> Selecto.from("store_inventory")
    |> Selecto.filter([{"store_id", 3}])
  )
```

### Validating Data Consistency

```elixir
# Find matching records between systems
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
|> Selecto.intersect(
    Selecto.select(["customer_id", "email"])
    |> Selecto.from("system_b_data")
  )
```

## EXCEPT Operations

### Finding Differences

```elixir
# Customers who haven't made purchases
selecto
|> Selecto.select(["customer_id", "email"])
|> Selecto.from("customers")
|> Selecto.except(
    Selecto.select(["DISTINCT customer_id", "email"])
    |> Selecto.from("orders")
    |> Selecto.join(:inner, "customers", on: "orders.customer_id = customers.id")
  )

# Products not in any active promotion
selecto
|> Selecto.select(["product_id", "name", "category"])
|> Selecto.from("products")
|> Selecto.filter([{"active", true}])
|> Selecto.except(
    Selecto.select(["p.product_id", "p.name", "p.category"])
    |> Selecto.from("products AS p")
    |> Selecto.join(:inner, "promotion_items AS pi", on: "p.product_id = pi.product_id")
    |> Selecto.join(:inner, "promotions AS pr", on: "pi.promotion_id = pr.id")
    |> Selecto.filter([
        {"pr.start_date", {:<=, "CURRENT_DATE"}},
        {"pr.end_date", {:>=, "CURRENT_DATE"}}
      ])
  )
```

### Data Quality Checks

```elixir
# Find orphaned records
selecto
|> Selecto.with_set_operation(:except, [
    # All order items
    {:query, fn ->
      Selecto.select(["order_id"])
      |> Selecto.from("order_items")
    end},
    
    # Valid orders
    {:query, fn ->
      Selecto.select(["id AS order_id"])
      |> Selecto.from("orders")
      |> Selecto.filter([{"status", {:!=, "deleted"}}])
    end}
  ])
|> Selecto.select(["order_id", {:literal, "Orphaned order item", as: "issue"}])
```

## Combining Multiple Set Operations

### Complex Set Combinations

```elixir
# Multi-level set operations
selecto
|> Selecto.with_cte("all_users", fn ->
    # Union of all user types
    Selecto.select(["id", "email", "name", {:literal, "customer", as: "user_type"}])
    |> Selecto.from("customers")
    |> Selecto.union_all(
      Selecto.select(["id", "email", "name", {:literal, "employee", as: "user_type"}])
      |> Selecto.from("employees")
    )
    |> Selecto.union_all(
      Selecto.select(["id", "email", "name", {:literal, "vendor", as: "user_type"}])
      |> Selecto.from("vendors")
    )
  end)
|> Selecto.with_cte("active_users", fn ->
    # Users with recent activity
    Selecto.select(["DISTINCT user_id AS id"])
    |> Selecto.from("activity_log")
    |> Selecto.filter([{"timestamp", {:>, "CURRENT_DATE - INTERVAL '90 days'"}}])
  end)
|> Selecto.select(["au.id", "au.email", "au.name", "au.user_type"])
|> Selecto.from("all_users AS au")
|> Selecto.intersect(
    Selecto.select(["au2.id", "au2.email", "au2.name", "au2.user_type"])
    |> Selecto.from("all_users AS au2")
    |> Selecto.join(:inner, "active_users AS act", on: "au2.id = act.id")
  )
```

### Parenthesized Set Operations

```elixir
# (A UNION B) EXCEPT (C UNION D)
selecto
|> Selecto.with_cte("set_ab", fn ->
    Selecto.select(["product_id"])
    |> Selecto.from("warehouse_a")
    |> Selecto.union(
      Selecto.select(["product_id"])
      |> Selecto.from("warehouse_b")
    )
  end)
|> Selecto.with_cte("set_cd", fn ->
    Selecto.select(["product_id"])
    |> Selecto.from("warehouse_c")
    |> Selecto.union(
      Selecto.select(["product_id"])
      |> Selecto.from("warehouse_d")
    )
  end)
|> Selecto.select(["product_id"])
|> Selecto.from("set_ab")
|> Selecto.except(
    Selecto.select(["product_id"])
    |> Selecto.from("set_cd")
  )
```

## Set Operations with CTEs

### Recursive Set Operations

```elixir
# Hierarchical data with set operations
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
          "ct.level + 1 AS level"
        ])
      |> Selecto.from("categories AS c")
      |> Selecto.join(:inner, "category_tree AS ct", on: "c.parent_id = ct.id")
      |> Selecto.filter([{"ct.level", {:<, 5}}])
    end
  )
|> Selecto.with_cte("active_categories", fn ->
    Selecto.select(["DISTINCT category_id AS id"])
    |> Selecto.from("products")
    |> Selecto.filter([{"discontinued", false}])
  end)
|> Selecto.select(["*"])
|> Selecto.from("category_tree")
|> Selecto.intersect(
    Selecto.select(["ct.*"])
    |> Selecto.from("category_tree AS ct")
    |> Selecto.join(:inner, "active_categories AS ac", on: "ct.id = ac.id")
  )
```

## Advanced Patterns

### Symmetric Difference

```elixir
# A ∆ B = (A - B) ∪ (B - A)
defmodule SetOperations do
  def symmetric_difference(selecto, set_a, set_b) do
    # Elements in A but not B
    a_minus_b = 
      set_a
      |> Selecto.except(set_b)
    
    # Elements in B but not A
    b_minus_a =
      set_b
      |> Selecto.except(set_a)
    
    # Union of both differences
    a_minus_b
    |> Selecto.union(b_minus_a)
  end
end

# Usage: Find products with price differences between regions
SetOperations.symmetric_difference(
  selecto,
  Selecto.select(["product_id", "price"])
  |> Selecto.from("prices_region_a"),
  Selecto.select(["product_id", "price"])
  |> Selecto.from("prices_region_b")
)
```

### Incremental Data Processing

```elixir
# Process only new/changed records
selecto
|> Selecto.with_cte("current_snapshot", fn ->
    Selecto.select(["id", "data_hash", "updated_at"])
    |> Selecto.from("data_warehouse")
  end)
|> Selecto.with_cte("new_data", fn ->
    Selecto.select(["id", "MD5(data::text) AS data_hash", "updated_at"])
    |> Selecto.from("source_system")
    |> Selecto.except(
      Selecto.select(["id", "data_hash", "updated_at"])
      |> Selecto.from("current_snapshot")
    )
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
```

### Data Validation Patterns

```elixir
# Comprehensive data validation using set operations
selecto
|> Selecto.with_cte("required_fields", fn ->
    # All records must have these fields
    Selecto.select(["id"])
    |> Selecto.from("records")
    |> Selecto.filter([
        {:not_null, "required_field_1"},
        {:not_null, "required_field_2"}
      ])
  end)
|> Selecto.with_cte("valid_references", fn ->
    # All foreign keys must be valid
    Selecto.select(["r.id"])
    |> Selecto.from("records AS r")
    |> Selecto.join(:inner, "reference_table AS ref", 
        on: "r.reference_id = ref.id")
  end)
|> Selecto.with_cte("valid_records", fn ->
    # Intersection of all validations
    Selecto.select(["id"])
    |> Selecto.from("required_fields")
    |> Selecto.intersect(
      Selecto.select(["id"])
      |> Selecto.from("valid_references")
    )
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
```

## Performance Optimization

### Index Strategies

```sql
-- Indexes for set operations
-- Ensure all columns in SELECT are indexed
CREATE INDEX idx_customers_email_name ON customers(email, name);
CREATE INDEX idx_employees_email_name ON employees(email, name);

-- For large EXCEPT operations
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- For INTERSECT with filters
CREATE INDEX idx_inventory_store_product 
  ON store_inventory(store_id, product_id);
```

### Query Optimization

```elixir
# GOOD: Use UNION ALL when duplicates don't matter
selecto
|> Selecto.union_all(query2)  # Faster, no duplicate removal

# GOOD: Filter before set operations
selecto
|> Selecto.filter([{"active", true}])
|> Selecto.union(
    query2 |> Selecto.filter([{"status", "enabled"}])
  )

# AVOID: Set operations on large unfiltered tables
selecto
|> Selecto.from("huge_table_1")  # Millions of rows
|> Selecto.union(
    Selecto.from("huge_table_2")  # Millions of rows
  )

# BETTER: Use CTEs to pre-filter
|> Selecto.with_cte("filtered_1", fn ->
    Selecto.from("huge_table_1")
    |> Selecto.filter([{"date", {:>=, "2024-01-01"}}])
  end)
```

### Choosing the Right Operation

```elixir
# Use EXISTS instead of EXCEPT for existence checks
# SLOWER: Using EXCEPT
selecto
|> Selecto.select(["id"])
|> Selecto.from("table_a")
|> Selecto.except(
    Selecto.select(["id"])
    |> Selecto.from("table_b")
  )

# FASTER: Using NOT EXISTS
selecto
|> Selecto.select(["id"])
|> Selecto.from("table_a")
|> Selecto.filter([
    {:not_exists, fn ->
      Selecto.from("table_b")
      |> Selecto.filter([{"table_b.id", {:ref, "table_a.id"}}])
    end}
  ])
```

## Best Practices

### 1. Column Alignment

```elixir
# GOOD: Same number and types of columns
selecto
|> Selecto.select(["id", "name", "email"])
|> Selecto.union(
    Selecto.select(["user_id AS id", "full_name AS name", "email_address AS email"])
  )

# BAD: Mismatched columns
selecto
|> Selecto.select(["id", "name"])
|> Selecto.union(
    Selecto.select(["id", "name", "email"])  # Different column count!
  )
```

### 2. Use Type Casting

```elixir
# Ensure compatible types
selecto
|> Selecto.select([
    "id",
    {:cast, "amount", :decimal, as: "value"}
  ])
|> Selecto.union(
    Selecto.select([
        "id",
        {:cast, "price", :decimal, as: "value"}
      ])
  )
```

### 3. Order By Placement

```elixir
# ORDER BY goes after all set operations
selecto
|> Selecto.select(["name", "type"])
|> Selecto.from("employees")
|> Selecto.union(
    Selecto.select(["name", {:literal, "Contractor", as: "type"}])
    |> Selecto.from("contractors")
  )
|> Selecto.order_by([{"name", :asc}])  # After UNION
```

### 4. Optimize with CTEs

```elixir
# Pre-compute complex queries
selecto
|> Selecto.with_cte("complex_calc", fn ->
    # Expensive calculation done once
    Selecto.select(["id", "complex_function(data) AS result"])
    |> Selecto.from("large_table")
  end)
|> Selecto.select(["*"])
|> Selecto.from("complex_calc")
|> Selecto.filter([{"result", {:>, 100}}])
|> Selecto.union(
    Selecto.select(["*"])
    |> Selecto.from("complex_calc")
    |> Selecto.filter([{"result", {:<, -100}}])
  )
```

## Common Use Cases

### Merging Time-Series Data

```elixir
# Combine data from multiple time periods
selecto
|> Selecto.select([
    "date",
    "metric",
    "value",
    {:literal, "real-time", as: "source"}
  ])
|> Selecto.from("realtime_metrics")
|> Selecto.filter([{"date", {:>=, "CURRENT_DATE"}}])
|> Selecto.union_all(
    Selecto.select([
        "date",
        "metric", 
        "value",
        {:literal, "historical", as: "source"}
      ])
    |> Selecto.from("historical_metrics")
    |> Selecto.filter([{"date", {:<, "CURRENT_DATE"}}])
  )
|> Selecto.order_by([{"date", :desc}, {"metric", :asc}])
```

### Deduplication

```elixir
# Remove duplicates across tables
selecto
|> Selecto.with_cte("all_emails", fn ->
    Selecto.select(["email", "MIN(created_at) AS first_seen"])
    |> Selecto.from("(
        SELECT email, created_at FROM customers
        UNION ALL
        SELECT email, created_at FROM newsletter_subscribers
        UNION ALL
        SELECT email, registered_at AS created_at FROM users
      ) AS combined")
    |> Selecto.group_by(["email"])
  end)
|> Selecto.select(["DISTINCT ON (email) email", "first_seen"])
|> Selecto.from("all_emails")
|> Selecto.order_by(["email", "first_seen"])
```

### Gap Analysis

```elixir
# Find missing records
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
|> Selecto.except(
    Selecto.select(["DISTINCT DATE(created_at) AS date"])
    |> Selecto.from("daily_reports")
  )
|> Selecto.order_by([{"date", :asc}])
```

## Error Handling

### Common Errors

```elixir
# ERROR: each UNION query must have the same number of columns
# Solution: Ensure all queries have same column count
|> Selecto.select(["id", "name", {:literal, nil, as: "email"}])  # Add placeholder

# ERROR: UNION types text and integer cannot be matched
# Solution: Cast to common type
|> Selecto.select([{:cast, "id", :text}, "name"])

# ERROR: column "x" does not exist
# Solution: Use column aliases consistently
|> Selecto.select(["id AS user_id", "name"])
|> Selecto.union(
    Selecto.select(["customer_id AS user_id", "full_name AS name"])
  )
```

## PostgreSQL Version Compatibility

| Feature | Min Version | Notes |
|---------|-------------|-------|
| Basic set operations | All | UNION, INTERSECT, EXCEPT |
| UNION ALL | All | No duplicate removal |
| INTERSECT ALL | 8.4+ | Keep duplicate rows |
| EXCEPT ALL | 8.4+ | Keep duplicate rows |
| Parenthesized set ops | All | (A UNION B) EXCEPT C |

## See Also

- [PostgreSQL Set Operations](https://www.postgresql.org/docs/current/queries-union.html)
- [Common Table Expressions Guide](./cte.md)
- [Subqueries Guide](./subqueries.md)
- [Performance Tuning Guide](./performance.md)