# LATERAL Joins Guide

## Overview

LATERAL joins are a powerful PostgreSQL feature that allows the right side of a join to reference columns from the left side, enabling correlated subqueries in the FROM clause. This is particularly useful for row-wise operations, top-N queries per group, and dynamic function calls.

**Important:** LATERAL joins in Selecto use the `lateral_join` function. The callback receives a base Selecto instance that you should configure with your domain and connection. The third parameter is the alias for the lateral subquery, and the fourth (optional) parameter contains join conditions.

## Table of Contents

1. [Understanding LATERAL](#understanding-lateral)
2. [Basic LATERAL Joins](#basic-lateral-joins)
3. [LATERAL with Subqueries](#lateral-with-subqueries)
4. [LATERAL with Functions](#lateral-with-functions)
5. [Advanced Patterns](#advanced-patterns)
6. [Performance Optimization](#performance-optimization)
7. [Common Use Cases](#common-use-cases)

## Understanding LATERAL

### What Makes LATERAL Special

Traditional joins cannot reference columns from other tables in the FROM clause:

```sql
-- This DOESN'T work without LATERAL:
SELECT c.name, recent.*
FROM customer c
JOIN (
  SELECT COUNT(*) as order_count
  FROM orders o
  WHERE o.customer_id = c.customer_id  -- Can't reference c.customer_id!
) recent ON true;

-- This WORKS with LATERAL:
SELECT c.name, recent.*
FROM customer c
LEFT JOIN LATERAL (
  SELECT COUNT(*) as order_count
  FROM orders o
  WHERE o.customer_id = c.customer_id  -- Can reference c.customer_id!
) recent ON true;
```

## Basic LATERAL Joins

### Simple Correlated Subquery

```elixir
# Get the 3 most recent orders for each customer - CORRECT API
selecto
|> Selecto.lateral_join(
    :left,
    fn _base ->
      Selecto.configure(order_domain, connection)
      |> Selecto.select(["order_id", "order_date", "total"])
      |> Selecto.from("orders")  # Specify the table
      |> Selecto.filter([{"customer_id", {:ref, "customer.customer_id"}}])
      |> Selecto.order_by([{"order_date", :desc}])
      |> Selecto.limit(3)
    end,
    "recent_orders",  # Alias as string, not keyword list
    []  # Optional join conditions
  )
|> Selecto.select([
    "customer.name",
    "recent_orders.order_id",
    "recent_orders.order_date",
    "recent_orders.total"
  ])
```

**Generated SQL:**
```sql
SELECT customer.name, 
       recent_orders.order_id,
       recent_orders.order_date,
       recent_orders.total
FROM customer
LEFT JOIN LATERAL (
  SELECT order_id, order_date, total
  FROM orders
  WHERE customer_id = customer.customer_id
  ORDER BY order_date DESC
  LIMIT 3
) recent_orders ON true;
```

### Multiple Column References

```elixir
# Find products similar to customer's previous purchases - CORRECT API
selecto
|> Selecto.lateral_join(
    :left,
    fn _base ->
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
    "similar_products",  # Alias as string
    []  # Optional join conditions
  )
|> Selecto.select([
    "customer.name",
    "similar_products.product_name",
    "similar_products.similarity_score"
  ])
```

## LATERAL with Subqueries

### Aggregations Per Row

```elixir
# Get aggregated statistics for each entity
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
      Selecto.configure(rental_domain, connection)
      |> Selecto.select([
          {:count, "*", as: "total_rentals"},
          {:sum, "payment.amount", as: "total_revenue"},
          {:avg, "EXTRACT(DAY FROM return_date - rental_date)", as: "avg_rental_duration"}
        ])
      |> Selecto.join(:inner, "inventory", on: "rental.inventory_id = inventory.inventory_id")
      |> Selecto.join(:left, "payment", on: "rental.rental_id = payment.rental_id")
      |> Selecto.filter([{"inventory.film_id", {:ref, "film.film_id"}}])
    end,
    as: "rental_stats"
  )
|> Selecto.order_by([{"rental_stats.total_revenue", :desc_nulls_last}])
```

### Dynamic Filtering

```elixir
# Apply dynamic filters based on row values
selecto
|> Selecto.select([
    "category.name AS category",
    "recommended.title",
    "recommended.rating"
  ])
|> Selecto.lateral_join(
    :cross,
    fn base ->
      Selecto.configure(film_domain, connection)
      |> Selecto.select(["title", "rating", "rental_rate"])
      |> Selecto.filter([
          # Different criteria based on category
          {:case_when, [
            {[{:ref, "category.name"}, {:=, "Children"}],
             {:in, "rating", ["G", "PG"]}},
            {[{:ref, "category.name"}, {:=, "Horror"}],
             {:in, "rating", ["R", "NC-17"]}},
            {[true], {:not_null, "rating"}}
          ]},
          # Price range based on category
          {"rental_rate", {:between, 
            {:ref, "category.min_price"}, 
            {:ref, "category.max_price"}}}
        ])
      |> Selecto.order_by([{"rental_rate", :desc}])
      |> Selecto.limit(3)
    end,
    as: "recommended"
  )
```

## LATERAL with Functions

### Table-Returning Functions

```elixir
# Use LATERAL with PostgreSQL functions
selecto
|> Selecto.select([
    "document.id",
    "document.title",
    "word",
    "position"
  ])
|> Selecto.lateral_join(
    :cross,
    {:function, "regexp_split_to_table", [
      {:ref, "document.content"},
      "\\s+"
    ], with_ordinality: true},
    as: "word"
  )
|> Selecto.filter([{:length, "word", {:>, 3}}])

# JSON array expansion
selecto
|> Selecto.select([
    "product.name",
    "tag.value AS tag"
  ])
|> Selecto.lateral_join(
    :cross,
    {:function, "jsonb_array_elements_text", [{:ref, "product.tags"}]},
    as: "tag"
  )
```

**Generated SQL:**
```sql
-- Text splitting
SELECT document.id, document.title, word, position
FROM document
CROSS JOIN LATERAL 
  regexp_split_to_table(document.content, '\s+') 
  WITH ORDINALITY AS word(value, position)
WHERE LENGTH(word.value) > 3;

-- JSON expansion
SELECT product.name, tag.value AS tag
FROM product
CROSS JOIN LATERAL 
  jsonb_array_elements_text(product.tags) AS tag(value);
```

### Custom Functions

```elixir
# Call custom PostgreSQL functions with row context
selecto
|> Selecto.select([
    "customer.name",
    "risk.score",
    "risk.factors"
  ])
|> Selecto.lateral_join(
    :left,
    {:function, "calculate_credit_risk", [
      {:ref, "customer.customer_id"},
      {:ref, "customer.registration_date"},
      {:literal, "CURRENT_DATE"}
    ]},
    as: "risk"
  )
|> Selecto.filter([{"risk.score", {:>, 0.7}}])
```

## Advanced Patterns

### Top-N Per Group

```elixir
# Get top 3 highest-grossing films per category
selecto
|> Selecto.select([
    "category.name AS category",
    "top_films.title",
    "top_films.total_revenue"
  ])
|> Selecto.from("category")
|> Selecto.lateral_join(
    :left,
    fn base ->
      Selecto.configure(film_domain, connection)
      |> Selecto.select([
          "film.title",
          {:sum, "payment.amount", as: "total_revenue"}
        ])
      |> Selecto.join(:inner, "film_category", 
          on: "film.film_id = film_category.film_id")
      |> Selecto.join(:inner, "inventory", 
          on: "film.film_id = inventory.film_id")
      |> Selecto.join(:inner, "rental", 
          on: "inventory.inventory_id = rental.inventory_id")
      |> Selecto.join(:inner, "payment", 
          on: "rental.rental_id = payment.rental_id")
      |> Selecto.filter([{"film_category.category_id", {:ref, "category.category_id"}}])
      |> Selecto.group_by(["film.film_id", "film.title"])
      |> Selecto.order_by([{"total_revenue", :desc}])
      |> Selecto.limit(3)
    end,
    as: "top_films"
  )
|> Selecto.order_by(["category.name", {"top_films.total_revenue", :desc}])
```

### Running Calculations

```elixir
# Calculate running totals with context
selecto
|> Selecto.select([
    "account.account_id",
    "transaction.date",
    "transaction.amount",
    "balance.running_balance"
  ])
|> Selecto.from("account")
|> Selecto.join(:inner, "transaction", 
    on: "account.account_id = transaction.account_id")
|> Selecto.lateral_join(
    :left,
    fn base ->
      Selecto.select([
          {:sum, "t2.amount", as: "running_balance"}
        ])
      |> Selecto.from("transaction AS t2")
      |> Selecto.filter([
          {"t2.account_id", {:ref, "account.account_id"}},
          {"t2.date", {:<=, {:ref, "transaction.date"}}}
        ])
    end,
    as: "balance"
  )
|> Selecto.order_by(["account.account_id", "transaction.date"])
```

### Recursive-like Patterns

```elixir
# Find related items through multiple hops
selecto
|> Selecto.select([
    "item.id AS source_item",
    "related1.item_id AS related_level_1",
    "related2.item_id AS related_level_2"
  ])
|> Selecto.from("item")
|> Selecto.lateral_join(
    :left,
    fn base ->
      Selecto.select(["related_item_id AS item_id", "score"])
      |> Selecto.from("item_similarity")
      |> Selecto.filter([
          {"item_id", {:ref, "item.id"}},
          {"score", {:>, 0.5}}
        ])
      |> Selecto.order_by([{"score", :desc}])
      |> Selecto.limit(5)
    end,
    as: "related1"
  )
|> Selecto.lateral_join(
    :left,
    fn base ->
      Selecto.select(["related_item_id AS item_id", "score"])
      |> Selecto.from("item_similarity")
      |> Selecto.filter([
          {"item_id", {:ref, "related1.item_id"}},
          {"related_item_id", {:!=, {:ref, "item.id"}}},
          {"score", {:>, 0.3}}
        ])
      |> Selecto.order_by([{"score", :desc}])
      |> Selecto.limit(3)
    end,
    as: "related2"
  )
```

## Performance Optimization

### Index Strategies

```sql
-- Indexes for LATERAL join correlations
CREATE INDEX idx_orders_customer_date 
  ON orders(customer_id, order_date DESC);

CREATE INDEX idx_inventory_film 
  ON inventory(film_id);

-- Covering indexes for LATERAL subqueries
CREATE INDEX idx_rental_inventory_dates 
  ON rental(inventory_id, rental_date, return_date) 
  INCLUDE (rental_id);
```

### Query Planning

```elixir
# Materialized CTE + LATERAL for complex queries
selecto
|> Selecto.with_cte("active_customers", 
    fn ->
      Selecto.filter([{"status", "active"}])
      |> Selecto.filter([{"last_order_date", {:>, "2024-01-01"}}])
    end,
    materialized: true
  )
|> Selecto.from("active_customers AS c")
|> Selecto.lateral_join(
    :left,
    fn base ->
      # Now operates on smaller dataset
      expensive_calculation()
    end,
    as: "calc"
  )
```

### Optimization Patterns

```elixir
# GOOD: Limit rows in LATERAL subquery
|> Selecto.lateral_join(:left, fn base ->
    query |> Selecto.limit(10)
  end, as: "limited")

# AVOID: Unbounded LATERAL subqueries
|> Selecto.lateral_join(:left, fn base ->
    query  # No limit - processes all rows
  end, as: "unlimited")

# GOOD: Push filters into LATERAL
|> Selecto.lateral_join(:left, fn base ->
    query 
    |> Selecto.filter([{"active", true}])
    |> Selecto.filter([{"date", {:>, "2024-01-01"}}])
  end, as: "filtered")

# GOOD: Use EXISTS instead of LATERAL for existence checks
|> Selecto.filter([
    {:exists, fn ->
      Selecto.from("orders")
      |> Selecto.filter([{"customer_id", {:ref, "customer.id"}}])
    end}
  ])
```

## Common Use Cases

### Latest Record Per Group

```elixir
# Get the latest status for each order
selecto
|> Selecto.select([
    "order.id",
    "order.customer_id",
    "latest_status.status",
    "latest_status.updated_at"
  ])
|> Selecto.from("orders AS order")
|> Selecto.lateral_join(
    :left,
    fn base ->
      Selecto.select(["status", "updated_at"])
      |> Selecto.from("order_status")
      |> Selecto.filter([{"order_id", {:ref, "order.id"}}])
      |> Selecto.order_by([{"updated_at", :desc}])
      |> Selecto.limit(1)
    end,
    as: "latest_status"
  )
```

### Dynamic Aggregations

```elixir
# Calculate different metrics based on product type
selecto
|> Selecto.select([
    "product.name",
    "product.type",
    "metrics.*"
  ])
|> Selecto.from("product")
|> Selecto.lateral_join(
    :left,
    fn base ->
      Selecto.select([
          {:case_when, [
            {[{:ref, "product.type"}, {:=, "digital"}],
             {:count, "download.id"}},
            {[{:ref, "product.type"}, {:=, "physical"}],
             {:count, "shipment.id"}},
            {[true], {:literal, 0}}
          ], as: "activity_count"},
          
          {:case_when, [
            {[{:ref, "product.type"}, {:=, "subscription"}],
             {:avg, "subscription.monthly_fee"}},
            {[true],
             {:avg, "order_item.price"}}
          ], as: "avg_value"}
        ])
      |> Selecto.from(
          {:case_when, [
            {[{:ref, "product.type"}, {:=, "digital"}], "download"},
            {[{:ref, "product.type"}, {:=, "physical"}], "shipment"},
            {[{:ref, "product.type"}, {:=, "subscription"}], "subscription"},
            {[true], "order_item"}
          ]}
        )
      |> Selecto.filter([{"product_id", {:ref, "product.id"}}])
    end,
    as: "metrics"
  )
```

### Sampling and Analysis

```elixir
# Sample recent activity for each user
selecto
|> Selecto.select([
    "user.email",
    "sample.action",
    "sample.timestamp"
  ])
|> Selecto.from("users AS user")
|> Selecto.lateral_join(
    :left,
    fn base ->
      Selecto.select(["action", "timestamp"])
      |> Selecto.from("user_activity")
      |> Selecto.filter([
          {"user_id", {:ref, "user.id"}},
          {"timestamp", {:>, "CURRENT_TIMESTAMP - INTERVAL '7 days'"}}
        ])
      |> Selecto.order_by([{:random, nil}])  # Random sampling
      |> Selecto.limit(10)
    end,
    as: "sample"
  )
```

## Comparison with Alternatives

### LATERAL vs Correlated Subquery in SELECT

```elixir
# Using LATERAL (can return multiple columns/rows)
selecto
|> Selecto.lateral_join(:left, fn base ->
    Selecto.select(["count", "sum", "avg"])
    |> Selecto.from("orders")
    |> Selecto.filter([{"customer_id", {:ref, "c.id"}}])
  end, as: "stats")

# Using subquery in SELECT (single value only)
selecto
|> Selecto.select([
    "c.name",
    {:subquery, fn ->
      Selecto.select([{:count, "*"}])
      |> Selecto.from("orders")
      |> Selecto.filter([{"customer_id", {:ref, "c.id"}}])
    end, as: "order_count"}
  ])
```

### LATERAL vs Window Functions

```elixir
# LATERAL: Different subquery per row
|> Selecto.lateral_join(:left, fn base ->
    custom_query_based_on_row_values()
  end)

# Window: Same calculation over partitions
|> Selecto.select([
    {:row_number, over: "PARTITION BY category ORDER BY price DESC"}
  ])
```

## Error Handling

### Common Errors

```elixir
# ERROR: invalid reference to FROM-clause entry for table "customer"
# Solution: Use LATERAL for correlated references
|> Selecto.lateral_join(...)  # Not just join()

# ERROR: LATERAL query cannot be independent
# Solution: Reference outer query columns
lateral_join(:left, fn base ->
  query
  |> Selecto.filter([{"field", {:ref, "outer.column"}}])  # Must reference outer
end)

# ERROR: column reference is ambiguous
# Solution: Use table aliases
|> Selecto.from("customer AS c")
|> Selecto.lateral_join(:left, fn base ->
  query |> Selecto.filter([{"customer_id", {:ref, "c.customer_id"}}])
end, as: "lat")
```

## PostgreSQL Version Compatibility

| Feature | Min Version | Notes |
|---------|-------------|-------|
| LATERAL keyword | 9.3+ | Core LATERAL support |
| LATERAL with VALUES | 9.3+ | Inline value tables |
| LATERAL with functions | 9.3+ | Table functions |
| LATERAL with UPDATE/DELETE | 9.5+ | DML support |

## Best Practices

1. **Use appropriate join type**: LEFT LATERAL for optional data, CROSS LATERAL when always present
2. **Limit result sets**: Always use LIMIT in LATERAL subqueries when appropriate
3. **Index correlation columns**: Ensure join conditions are indexed
4. **Consider alternatives**: Sometimes EXISTS or IN is more efficient
5. **Test with EXPLAIN**: Verify query plans for large datasets

## See Also

- [PostgreSQL LATERAL Documentation](https://www.postgresql.org/docs/current/queries-table-expressions.html#QUERIES-LATERAL)
- [Common Table Expressions Guide](./cte.md)
- [Window Functions Guide](./window-functions.md)
- [Subqueries Guide](./subqueries.md)