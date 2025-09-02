# Subqueries and Subfilters Guide

## Overview

Subqueries and subfilters enable complex nested queries and advanced filtering patterns in Selecto. This guide covers scalar subqueries, correlated subqueries, EXISTS/IN patterns, and Selecto's powerful subfilter system for filtering on related data through joins.

**Note:** The subquery patterns shown in this guide represent conceptual SQL patterns. Selecto's actual implementation may require using CTEs, joins, or other approaches to achieve similar results. Check the actual API documentation for supported patterns.

## Table of Contents

1. [Scalar Subqueries](#scalar-subqueries)
2. [Subqueries in FROM Clause](#subqueries-in-from-clause)
3. [EXISTS and NOT EXISTS](#exists-and-not-exists)
4. [IN and NOT IN](#in-and-not-in)
5. [ANY, ALL, and SOME](#any-all-and-some)
6. [Correlated Subqueries](#correlated-subqueries)
7. [Subfilters System](#subfilters-system)
8. [Advanced Patterns](#advanced-patterns)
9. [Performance Optimization](#performance-optimization)

## Scalar Subqueries

### Subqueries in SELECT

```elixir
# Single value subquery
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

# Subquery with COALESCE for null handling
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
```

**Generated SQL:**
```sql
-- Order count and total spent
SELECT 
  customer.name,
  customer.email,
  (SELECT COUNT(*) FROM orders WHERE customer_id = customer.id) AS order_count,
  (SELECT SUM(amount) FROM payments WHERE customer_id = customer.id) AS total_spent
FROM customer;

-- With COALESCE
SELECT 
  product.name,
  COALESCE(
    (SELECT AVG(rating) FROM reviews WHERE product_id = product.id),
    0
  ) AS avg_rating
FROM product;
```

### Subqueries in WHERE

```elixir
# Filter using subquery result
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

# Multiple subquery conditions
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
```

## Subqueries in FROM Clause

### Derived Tables

```elixir
# Using subquery as table source
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

# Join with subquery
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
```

## EXISTS and NOT EXISTS

### Existence Checks

```elixir
# EXISTS pattern
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

# NOT EXISTS pattern
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

# Multiple EXISTS conditions
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
```

## IN and NOT IN

### Set Membership Tests

```elixir
# IN with subquery
selecto
|> Selecto.select(["product.*"])
|> Selecto.filter([
    {"category_id", {:in, 
      {:subquery, fn ->
        Selecto.select(["id"])
        |> Selecto.from("categories")
        |> Selecto.filter([{"active", true}])
      end}
    }}
  ])

# NOT IN with subquery
selecto
|> Selecto.select(["customer.*"])
|> Selecto.filter([
    {"id", {:not_in,
      {:subquery, fn ->
        Selecto.select(["DISTINCT customer_id"])
        |> Selecto.from("blacklist")
        |> Selecto.filter([{"active", true}])
      end}
    }}
  ])

# IN with values list
selecto
|> Selecto.filter([
    {"status", {:in, ["pending", "processing", "shipped"]}},
    {"region", {:not_in, ["restricted", "embargo"]}}
  ])
```

## ANY, ALL, and SOME

### Quantified Comparisons

```elixir
# ANY (SOME is synonym)
selecto
|> Selecto.select(["product.*"])
|> Selecto.filter([
    {"price", {:<, {:any,
      {:subquery, fn ->
        Selecto.select(["price"])
        |> Selecto.from("competitor_prices")
        |> Selecto.filter([{"product_name", {:ref, "product.name"}}])
      end}
    }}}
  ])

# ALL comparison
selecto
|> Selecto.select(["employee.*"])
|> Selecto.filter([
    {"performance_score", {:>=, {:all,
      {:subquery, fn ->
        Selecto.select(["target_score"])
        |> Selecto.from("performance_targets")
        |> Selecto.filter([{"year", 2024}])
      end}
    }}}
  ])

# Complex ANY/ALL patterns
selecto
|> Selecto.select(["store.*"])
|> Selecto.filter([
    {:or, [
      {"revenue", {:>, {:any,
        {:subquery, fn ->
          Selecto.select(["revenue"])
          |> Selecto.from("stores")
          |> Selecto.filter([{"region", "competing_region"}])
        end}
      }}},
      {"customer_satisfaction", {:>=, {:all,
        {:subquery, fn ->
          Selecto.select(["min_satisfaction"])
          |> Selecto.from("quality_standards")
        end}
      }}}
    ]}
  ])
```

## Correlated Subqueries

### Row-by-Row Correlation

```elixir
# Correlated scalar subquery
selecto
|> Selecto.select([
    "e1.name",
    "e1.salary",
    "e1.department",
    {:subquery, fn ->
      Selecto.select([{:count, "*"}])
      |> Selecto.from("employees AS e2")
      |> Selecto.filter([
          {"e2.department", {:ref, "e1.department"}},
          {"e2.salary", {:>, {:ref, "e1.salary"}}}
        ])
    end, as: "employees_earning_more"}
  ])
|> Selecto.from("employees AS e1")

# Correlated UPDATE-style pattern
selecto
|> Selecto.select([
    "order.id",
    "order.total",
    {:subquery, fn ->
      Selecto.select([{:sum, "quantity * unit_price"}])
      |> Selecto.from("order_items")
      |> Selecto.filter([{"order_id", {:ref, "order.id"}}])
    end, as: "calculated_total"},
    {:case_when, [
        {[{:expr, "order.total != calculated_total"}], "Mismatch"},
        {[true], "OK"}
      ], as: "status"}
  ])
```

## Subfilters System

### Basic Subfilters

Selecto's subfilter system allows filtering parent records based on related data through joins:

```elixir
# Filter customers by order properties
selecto
|> Selecto.configure(customer_domain, connection)
|> Selecto.select(["customer.*"])
|> Selecto.subfilter([
    {"orders.total", {:>, 1000}},
    {"orders.status", "completed"}
  ])

# Multiple subfilter conditions
selecto
|> Selecto.select(["product.*"])
|> Selecto.subfilter([
    {"reviews.rating", {:>=, 4}},
    {"reviews.verified", true}
  ])
|> Selecto.subfilter([
    {"inventory.quantity", {:>, 0}},
    {"inventory.warehouse", "main"}
  ])
```

### Subfilter with Aggregations

```elixir
# Filter by aggregated related data
selecto
|> Selecto.select(["author.*"])
|> Selecto.subfilter([
    {:having, "posts", [
      {{:count, "*"}, {:>=, 10}},
      {{:avg, "views"}, {:>, 1000}}
    ]}
  ])

# Complex aggregation subfilters
selecto
|> Selecto.select(["category.*"])
|> Selecto.subfilter([
    {:having, "products", [
      {{:sum, "stock_quantity"}, {:>, 100}},
      {{:max, "price"}, {:<, 1000}},
      {{:min, "price"}, {:>, 10}}
    ]}
  ])
```

### Nested Subfilters

```elixir
# Filter through multiple relationships
selecto
|> Selecto.configure(store_domain, connection)
|> Selecto.select(["store.*"])
|> Selecto.subfilter([
    {"employees.departments.budget", {:>, 50000}},
    {"employees.departments.active", true}
  ])

# Deep nesting with conditions
selecto
|> Selecto.select(["customer.*"])
|> Selecto.subfilter([
    {"orders.items.product.category.name", "Electronics"},
    {"orders.items.quantity", {:>=, 2}},
    {"orders.payment.method", "credit_card"}
  ])
```

### Subfilter Modes

```elixir
# ANY mode (default) - at least one related record matches
selecto
|> Selecto.subfilter([
    {"orders.status", "completed"}
  ], mode: :any)

# ALL mode - all related records must match
selecto
|> Selecto.subfilter([
    {"orders.status", "completed"}
  ], mode: :all)

# NONE mode - no related records match
selecto
|> Selecto.subfilter([
    {"reviews.rating", {:<, 3}}
  ], mode: :none)

# EXISTS mode - related record exists
selecto
|> Selecto.subfilter([
    {"addresses.type", "billing"}
  ], mode: :exists)
```

## Advanced Patterns

### Recursive Subqueries

```elixir
# Find all subordinates recursively
selecto
|> Selecto.select([
    "e1.*",
    {:exists, fn ->
      Selecto.with_recursive_cte("subordinates",
        base_query: fn ->
          Selecto.select(["id"])
          |> Selecto.from("employees")
          |> Selecto.filter([{"manager_id", {:ref, "e1.id"}}])
        end,
        recursive_query: fn cte ->
          Selecto.select(["e.id"])
          |> Selecto.from("employees AS e")
          |> Selecto.join(:inner, cte, on: "e.manager_id = subordinates.id")
        end
      )
      |> Selecto.from("subordinates")
    end, as: "has_subordinates"}
  ])
|> Selecto.from("employees AS e1")
```

### Window Functions in Subqueries

```elixir
# Top N per group using subquery
selecto
|> Selecto.from({:subquery, fn ->
    Selecto.select([
        "*",
        {:row_number, 
          over: "PARTITION BY category ORDER BY price DESC",
          as: "price_rank"}
      ])
    |> Selecto.from("products")
  end, as: "ranked_products"})
|> Selecto.filter([{"price_rank", {:<=, 3}}])
```

### Dynamic Subqueries

```elixir
defmodule DynamicFilters do
  def apply_related_filters(selecto, filters) do
    Enum.reduce(filters, selecto, fn {table, conditions}, acc ->
      acc
      |> Selecto.filter([
          {:exists, fn ->
            Selecto.from(table)
            |> Selecto.filter(build_correlation(table, conditions))
          end}
        ])
    end)
  end
  
  defp build_correlation(table, conditions) do
    Enum.map(conditions, fn {field, value} ->
      {"#{table}.#{field}", value}
    end)
  end
end
```

## Performance Optimization

### Index Strategies

```sql
-- Indexes for correlated subqueries
CREATE INDEX idx_orders_customer_date 
  ON orders(customer_id, order_date DESC);

-- Covering index for EXISTS
CREATE INDEX idx_order_items_product 
  ON order_items(product_id) 
  INCLUDE (quantity, created_at);

-- Partial index for filtered subqueries
CREATE INDEX idx_active_products_category 
  ON products(category_id) 
  WHERE active = true;
```

### Query Optimization

```elixir
# GOOD: Use EXISTS instead of IN for large datasets
selecto
|> Selecto.filter([
    {:exists, fn ->
      Selecto.from("large_table")
      |> Selecto.filter([{"foreign_id", {:ref, "main.id"}}])
      |> Selecto.limit(1)  # Stop at first match
    end}
  ])

# AVOID: IN with large subquery result
selecto
|> Selecto.filter([
    {"id", {:in, 
      {:subquery, fn ->
        Selecto.from("huge_table")  # Returns thousands of IDs
      end}
    }}
  ])

# GOOD: Push down filters in subqueries
selecto
|> Selecto.from({:subquery, fn ->
    Selecto.from("orders")
    |> Selecto.filter([{"status", "completed"}])  # Filter early
    |> Selecto.group_by(["customer_id"])
  end})
```

### Subquery vs Join Decision

```elixir
# Use JOIN for simple equality and when you need columns from both tables
selecto
|> Selecto.select(["c.*", "o.order_count"])
|> Selecto.from("customers AS c")
|> Selecto.join(:left, 
    "(SELECT customer_id, COUNT(*) as order_count 
      FROM orders GROUP BY customer_id) AS o",
    on: "c.id = o.customer_id")

# Use subquery for complex logic or when you only need existence check
selecto
|> Selecto.select(["c.*"])
|> Selecto.from("customers AS c")
|> Selecto.filter([
    {:exists, fn ->
      Selecto.from("orders")
      |> Selecto.filter([
          {"customer_id", {:ref, "c.id"}},
          {:or, [
            {"status", "pending"},
            {"total", {:>, 1000}}
          ]}
        ])
    end}
  ])
```

## Common Use Cases

### Finding Duplicates

```elixir
# Find duplicate emails
selecto
|> Selecto.select(["c1.*"])
|> Selecto.from("customers AS c1")
|> Selecto.filter([
    {:exists, fn ->
      Selecto.from("customers AS c2")
      |> Selecto.filter([
          {"c2.email", {:ref, "c1.email"}},
          {"c2.id", {:!=, {:ref, "c1.id"}}}
        ])
    end}
  ])
|> Selecto.order_by(["email", "id"])
```

### Hierarchical Queries

```elixir
# Find leaf nodes (no children)
selecto
|> Selecto.select(["category.*"])
|> Selecto.filter([
    {:not_exists, fn ->
      Selecto.from("categories AS child")
      |> Selecto.filter([{"child.parent_id", {:ref, "category.id"}}])
    end}
  ])
```

### Data Validation

```elixir
# Find orphaned records
selecto
|> Selecto.select([
    "order_items.*",
    {:not_exists, fn ->
      Selecto.from("orders")
      |> Selecto.filter([{"id", {:ref, "order_items.order_id"}}])
    end, as: "is_orphaned"}
  ])
|> Selecto.filter([
    {:not_exists, fn ->
      Selecto.from("orders")
      |> Selecto.filter([{"id", {:ref, "order_items.order_id"}}])
    end}
  ])
```

## Error Handling

### Common Errors

```elixir
# ERROR: subquery must return only one column
# Solution: Ensure scalar subqueries return single value
{:subquery, fn ->
  Selecto.select([{:count, "*"}])  # Single column
  # Not: Selecto.select(["id", "name"])  # Multiple columns
end}

# ERROR: more than one row returned by a subquery used as an expression
# Solution: Use LIMIT or aggregate function
{:subquery, fn ->
  Selecto.select(["price"])
  |> Selecto.from("products")
  |> Selecto.order_by([{"price", :desc}])
  |> Selecto.limit(1)  # Ensure single row
end}

# ERROR: column reference is ambiguous
# Solution: Use table aliases
|> Selecto.from("orders AS o1")
|> Selecto.filter([
    {:exists, fn ->
      Selecto.from("orders AS o2")
      |> Selecto.filter([{"o2.customer_id", {:ref, "o1.customer_id"}}])
    end}
  ])
```

## Best Practices

1. **Use EXISTS for existence checks**: More efficient than IN for large datasets
2. **Correlate carefully**: Ensure outer references are properly qualified
3. **Limit subquery results**: Add LIMIT when expecting single row
4. **Index correlation columns**: Create indexes on columns used in WHERE
5. **Consider CTEs**: For complex subqueries, CTEs may be clearer
6. **Test NULL handling**: IN/NOT IN behave differently with NULLs

## See Also

- [Common Table Expressions Guide](./cte.md)
- [LATERAL Joins Guide](./lateral-joins.md)
- [Window Functions Guide](./window-functions.md)
- [Performance Tuning Guide](./performance.md)