# CASE Expressions Guide

## ⚠️ NOT YET IMPLEMENTED

**Important:** CASE expressions are not yet implemented in Selecto. This documentation describes the planned API and functionality. This is the only major SQL feature that still needs to be implemented.

## Overview

CASE expressions will provide conditional logic within SQL queries, allowing you to transform data based on conditions. Selecto will support both simple CASE (comparing a single expression) and searched CASE (evaluating multiple conditions) expressions, enabling powerful data transformations directly in your queries.

## Table of Contents

1. [Simple CASE Expressions](#simple-case-expressions)
2. [Searched CASE Expressions](#searched-case-expressions)
3. [CASE in Different Clauses](#case-in-different-clauses)
4. [Nested CASE Expressions](#nested-case-expressions)
5. [Advanced Patterns](#advanced-patterns)
6. [Performance Considerations](#performance-considerations)
7. [Best Practices](#best-practices)

## Simple CASE Expressions (Planned)

### Basic Simple CASE

Simple CASE expressions will compare a single expression against multiple values.

```elixir
# Basic value mapping (PLANNED API)
selecto
|> Selecto.select([
    "film.title",
    {:case, "film.rating",
      when: [
        {"G", "General Audiences"},
        {"PG", "Parental Guidance Suggested"},
        {"PG-13", "Parents Strongly Cautioned"},
        {"R", "Restricted"},
        {"NC-17", "Adults Only"}
      ],
      else: "Not Rated",
      as: "rating_description"
    }
  ])

# Numeric ranges mapping
selecto
|> Selecto.select([
    "product.name",
    "product.price",
    {:case, {:expr, "FLOOR(product.price / 100)"},
      when: [
        {0, "Under $100"},
        {1, "$ 100-$199"},
        {2, "$200-$299"},
        {3, "$300-$399"},
        {4, "$400-$499"}
      ],
      else: "$500+",
      as: "price_range"
    }
  ])
```

**Generated SQL:**
```sql
-- Basic mapping
SELECT film.title,
       CASE film.rating
         WHEN 'G' THEN 'General Audiences'
         WHEN 'PG' THEN 'Parental Guidance Suggested'
         WHEN 'PG-13' THEN 'Parents Strongly Cautioned'
         WHEN 'R' THEN 'Restricted'
         WHEN 'NC-17' THEN 'Adults Only'
         ELSE 'Not Rated'
       END AS rating_description
FROM film;

-- Numeric mapping
SELECT product.name, product.price,
       CASE FLOOR(product.price / 100)
         WHEN 0 THEN 'Under $100'
         WHEN 1 THEN '$100-$199'
         WHEN 2 THEN '$200-$299'
         WHEN 3 THEN '$300-$399'
         WHEN 4 THEN '$400-$499'
         ELSE '$500+'
       END AS price_range
FROM product;
```

### Simple CASE with NULL Handling

```elixir
# Handling NULL values
selecto
|> Selecto.select([
    "customer.name",
    {:case, "customer.status",
      when: [
        {"active", "Active Customer"},
        {"inactive", "Inactive"},
        {"pending", "Pending Approval"},
        {nil, "Status Unknown"}  # NULL handling
      ],
      else: "Invalid Status",
      as: "status_label"
    }
  ])

# Using COALESCE with CASE
selecto
|> Selecto.select([
    "order.id",
    {:case, {:coalesce, ["order.priority", 5]},
      when: [
        {1, "Critical"},
        {2, "High"},
        {3, "Medium"},
        {4, "Low"},
        {5, "Normal"}
      ],
      as: "priority_label"
    }
  ])
```

## Searched CASE Expressions (Planned)

### Basic Searched CASE

Searched CASE expressions will evaluate boolean conditions rather than comparing a single value.

```elixir
# Multiple condition evaluation (PLANNED API)
selecto
|> Selecto.select([
    "customer.name",
    "total_spent",
    {:case_when, [
        {[{"total_spent", {:>=, 10000}}], "Platinum"},
        {[{"total_spent", {:>=, 5000}}], "Gold"},
        {[{"total_spent", {:>=, 1000}}], "Silver"},
        {[{"total_spent", {:>, 0}}], "Bronze"}
      ],
      else: "Prospect",
      as: "customer_tier"
    }
  ])

# Complex conditions
selecto
|> Selecto.select([
    "employee.name",
    {:case_when, [
        {[
          {"department", "Sales"},
          {"years_experience", {:>, 5}},
          {"performance_rating", {:>=, 4}}
        ], "Senior Sales Expert"},
        {[
          {"department", "Sales"},
          {"years_experience", {:>, 2}}
        ], "Sales Professional"},
        {[
          {"department", "Engineering"},
          {"level", {:>=, 5}}
        ], "Senior Engineer"},
        {[
          {"department", "Engineering"}
        ], "Engineer"}
      ],
      else: "Staff",
      as: "role_classification"
    }
  ])
```

**Generated SQL:**
```sql
-- Tier classification
SELECT customer.name, total_spent,
       CASE 
         WHEN total_spent >= 10000 THEN 'Platinum'
         WHEN total_spent >= 5000 THEN 'Gold'
         WHEN total_spent >= 1000 THEN 'Silver'
         WHEN total_spent > 0 THEN 'Bronze'
         ELSE 'Prospect'
       END AS customer_tier
FROM customer;

-- Complex conditions
SELECT employee.name,
       CASE
         WHEN department = 'Sales' 
          AND years_experience > 5 
          AND performance_rating >= 4 THEN 'Senior Sales Expert'
         WHEN department = 'Sales' 
          AND years_experience > 2 THEN 'Sales Professional'
         WHEN department = 'Engineering' 
          AND level >= 5 THEN 'Senior Engineer'
         WHEN department = 'Engineering' THEN 'Engineer'
         ELSE 'Staff'
       END AS role_classification
FROM employee;
```

### CASE with OR/AND Logic

```elixir
# OR conditions
selecto
|> Selecto.select([
    "product.name",
    {:case_when, [
        {[{:or, [
          {"category", "Electronics"},
          {"category", "Computers"},
          {"brand", "TechCorp"}
        ]}], "Technology Product"},
        {[{:or, [
          {"category", "Clothing"},
          {"category", "Shoes"},
          {"category", "Accessories"}
        ]}], "Fashion Product"},
        {[true], "Other Product"}
      ],
      as: "product_group"
    }
  ])

# Mixed AND/OR
selecto
|> Selecto.select([
    "order.id",
    {:case_when, [
        {[{:and, [
          {"status", "pending"},
          {:or, [
            {"priority", 1},
            {"customer_tier", "Platinum"}
          ]}
        ]}], "Expedite"},
        {[{"status", "pending"}], "Normal Processing"},
        {[{"status", "completed"}], "Fulfilled"}
      ],
      else: "Review",
      as: "handling_instruction"
    }
  ])
```

## CASE in Different Clauses

### CASE in WHERE Clause

```elixir
# Conditional filtering
selecto
|> Selecto.filter([
    {:case_when, [
        {[{"user_role", "admin"}], true},
        {[{"user_role", "manager"}, {"department_id", current_dept}], true},
        {[{"user_role", "employee"}, {"user_id", current_user}], true}
      ],
      else: false}
  ])

# Dynamic date filtering
selecto
|> Selecto.filter([
    {"order_date", {:>=, 
      {:case_when, [
        {[{"customer_tier", "Platinum"}], "CURRENT_DATE - INTERVAL '1 year'"},
        {[{"customer_tier", "Gold"}], "CURRENT_DATE - INTERVAL '6 months'"},
        {[{"customer_tier", "Silver"}], "CURRENT_DATE - INTERVAL '3 months'"}
      ],
      else: "CURRENT_DATE - INTERVAL '1 month'"}
    }}
  ])
```

### CASE in ORDER BY Clause

```elixir
# Custom sorting logic
selecto
|> Selecto.order_by([
    {:case_when, [
        {[{"status", "critical"}], 1},
        {[{"status", "high"}], 2},
        {[{"status", "medium"}], 3},
        {[{"status", "low"}], 4}
      ],
      else: 5},
    {"created_date", :asc}
  ])

# Conditional sort direction
selecto
|> Selecto.order_by([
    {:case_when, [
        {[{"category", "Perishable"}], {"expiry_date", :asc}},
        {[{"category", "Electronics"}], {"warranty_date", :desc}},
        {[true], {"created_date", :desc}}
      ]}
  ])
```

### CASE in GROUP BY

```elixir
# Group by calculated categories
selecto
|> Selecto.select([
    {:case_when, [
        {[{"age", {:<, 18}}], "Minor"},
        {[{"age", {:between, 18, 65}}], "Adult"},
        {[{"age", {:>, 65}}], "Senior"}
      ],
      as: "age_group"},
    {:count, "*", as: "count"}
  ])
|> Selecto.group_by([
    {:case_when, [
        {[{"age", {:<, 18}}], "Minor"},
        {[{"age", {:between, 18, 65}}], "Adult"},
        {[{"age", {:>, 65}}], "Senior"}
      ]}
  ])
```

## Nested CASE Expressions

### Multiple Level Nesting

```elixir
# Nested CASE for complex logic
selecto
|> Selecto.select([
    "product.name",
    {:case_when, [
        {[{"category", "Electronics"}],
          {:case_when, [
            {[{"price", {:>, 1000}}], "Premium Electronics"},
            {[{"price", {:>, 500}}], "Mid-Range Electronics"},
            {[true], "Budget Electronics"}
          ]}},
        {[{"category", "Clothing"}],
          {:case_when, [
            {[{"brand", {:in, ["Gucci", "Prada", "Versace"]}}], "Luxury Fashion"},
            {[{"price", {:>, 100}}], "Premium Fashion"},
            {[true], "Affordable Fashion"}
          ]}},
        {[true], "Other"}
      ],
      as: "product_classification"
    }
  ])
```

**Generated SQL:**
```sql
SELECT product.name,
       CASE 
         WHEN category = 'Electronics' THEN
           CASE
             WHEN price > 1000 THEN 'Premium Electronics'
             WHEN price > 500 THEN 'Mid-Range Electronics'
             ELSE 'Budget Electronics'
           END
         WHEN category = 'Clothing' THEN
           CASE
             WHEN brand IN ('Gucci', 'Prada', 'Versace') THEN 'Luxury Fashion'
             WHEN price > 100 THEN 'Premium Fashion'
             ELSE 'Affordable Fashion'
           END
         ELSE 'Other'
       END AS product_classification
FROM product;
```

## Advanced Patterns

### CASE with Aggregations

```elixir
# Conditional aggregation
selecto
|> Selecto.select([
    "store.name",
    {:sum, {:case_when, [
        {[{"product.category", "Electronics"}], "sale.amount"},
        {[true], 0}
      ]}, as: "electronics_revenue"},
    {:sum, {:case_when, [
        {[{"product.category", "Clothing"}], "sale.amount"},
        {[true], 0}
      ]}, as: "clothing_revenue"},
    {:count, {:case_when, [
        {[{"sale.amount", {:>, 1000}}], 1},
        {[true], nil}
      ]}, as: "high_value_sales"}
  ])
|> Selecto.group_by(["store.store_id", "store.name"])
```

### CASE for Pivot Tables

```elixir
# Pivot data using CASE
selecto
|> Selecto.select([
    "salesperson.name",
    {:sum, {:case_when, [
        {[{"EXTRACT(MONTH FROM sale_date)", 1}], "amount"}
      ], else: 0}, as: "jan_sales"},
    {:sum, {:case_when, [
        {[{"EXTRACT(MONTH FROM sale_date)", 2}], "amount"}
      ], else: 0}, as: "feb_sales"},
    {:sum, {:case_when, [
        {[{"EXTRACT(MONTH FROM sale_date)", 3}], "amount"}
      ], else: 0}, as: "mar_sales"},
    # ... continue for other months
    {:sum, "amount", as: "total_sales"}
  ])
|> Selecto.filter([{"EXTRACT(YEAR FROM sale_date)", 2024}])
|> Selecto.group_by(["salesperson.salesperson_id", "salesperson.name"])
```

### Dynamic Column Generation

```elixir
# Generate columns based on data
selecto
|> Selecto.select([
    "customer.id",
    {:case_when, [
        {[{"config.output_format", "json"}],
          {:json_build_object, [
            "name", "customer.name",
            "email", "customer.email"
          ]}},
        {[{"config.output_format", "xml"}],
          {:xmlelement, "customer", [
            {:xmlforest, ["customer.name", "customer.email"]}
          ]}},
        {[true],
          {:concat, ["customer.name", ",", "customer.email"]}}
      ],
      as: "formatted_output"
    }
  ])
|> Selecto.join(:cross, "config")
```

### CASE with Subqueries

```elixir
# CASE with subquery conditions
selecto
|> Selecto.select([
    "product.name",
    {:case_when, [
        {[{:exists, fn ->
          Selecto.from("promotion")
          |> Selecto.filter([
              {"product_id", {:ref, "product.id"}},
              {"start_date", {:<=, "CURRENT_DATE"}},
              {"end_date", {:>=, "CURRENT_DATE"}}
            ])
        end}], "On Sale"},
        {[{:>, 
          {:subquery, fn ->
            Selecto.select([{:avg, "price"}])
            |> Selecto.from("product AS p2")
            |> Selecto.filter([{"p2.category", {:ref, "product.category"}}])
          end},
          {:ref, "product.price"}
        }], "Below Average Price"},
        {[true], "Regular Price"}
      ],
      as: "price_status"
    }
  ])
```

## Performance Considerations

### Index Usage with CASE

```sql
-- CASE expressions can prevent index usage
-- BAD: Function on indexed column
WHERE CASE WHEN status = 'active' THEN 1 ELSE 0 END = 1

-- GOOD: Direct condition
WHERE status = 'active'

-- Index for CASE in SELECT is not affected
CREATE INDEX idx_product_category ON products(category);
-- This still uses the index:
SELECT CASE category WHEN 'Electronics' THEN 'Tech' END FROM products;
```

### Optimization Strategies

```elixir
# Pre-calculate CASE results in CTE
selecto
|> Selecto.with_cte("categorized_products", fn ->
    Selecto.select([
        "*",
        {:case_when, [...], as: "price_category"}
      ])
    |> Selecto.from("products")
  end)
|> Selecto.select(["price_category", {:count, "*"}])
|> Selecto.from("categorized_products")
|> Selecto.group_by(["price_category"])

# Use computed columns for frequently used CASE
# ALTER TABLE customer ADD COLUMN tier TEXT 
#   GENERATED ALWAYS AS (
#     CASE 
#       WHEN total_spent >= 10000 THEN 'Platinum'
#       WHEN total_spent >= 5000 THEN 'Gold'
#       ELSE 'Silver'
#     END
#   ) STORED;
```

## Best Practices

### 1. Order Conditions Properly

```elixir
# GOOD: Most specific to least specific
{:case_when, [
    {[{"value", {:>, 1000}}], "Very High"},
    {[{"value", {:>, 500}}], "High"},
    {[{"value", {:>, 100}}], "Medium"},
    {[true], "Low"}
  ]}

# BAD: Less specific conditions first (will never reach later conditions)
{:case_when, [
    {[{"value", {:>, 100}}], "Medium"},
    {[{"value", {:>, 500}}], "High"},  # Never reached!
    {[{"value", {:>, 1000}}], "Very High"}  # Never reached!
  ]}
```

### 2. Always Include ELSE

```elixir
# GOOD: Explicit ELSE clause
{:case, "status",
  when: [
    {"active", "Active"},
    {"inactive", "Inactive"}
  ],
  else: "Unknown"  # Handles unexpected values
}

# RISKY: No ELSE returns NULL for unmatched
{:case, "status",
  when: [
    {"active", "Active"},
    {"inactive", "Inactive"}
  ]
  # Unmatched values become NULL
}
```

### 3. Use Appropriate CASE Type

```elixir
# GOOD: Simple CASE for single value comparison
{:case, "rating",
  when: [{"G", "General"}, {"PG", "Parental Guidance"}]
}

# GOOD: Searched CASE for complex conditions
{:case_when, [
    {[{"age", {:<, 13}}, {"rating", {:not_in, ["G", "PG"]}}], "Not Allowed"},
    {[{"age", {:<, 17}}, {"rating", "R"}], "Parental Guidance Required"}
  ]}

# AVOID: Searched CASE for simple equality
{:case_when, [
    {[{"rating", "G"}], "General"}  # Use simple CASE instead
  ]}
```

### 4. Consider NULL Handling

```elixir
# Handle NULLs explicitly
{:case_when, [
    {[{:is_null, "value"}], "No Value"},
    {[{"value", {:>, 100}}], "High"},
    {[true], "Normal"}
  ]}

# Or use COALESCE before CASE
{:case, {:coalesce, ["status", "unknown"]},
  when: [...]
}
```

## Common Use Cases

### Data Classification

```elixir
# Customer segmentation
selecto
|> Selecto.select([
    "customer.*",
    {:case_when, [
        {[
          {"recency_days", {:<=, 30}},
          {"frequency", {:>=, 10}},
          {"monetary", {:>=, 1000}}
        ], "Champion"},
        {[
          {"recency_days", {:<=, 60}},
          {"frequency", {:>=, 5}},
          {"monetary", {:>=, 500}}
        ], "Loyal"},
        {[
          {"recency_days", {:>, 180}}
        ], "At Risk"},
        {[true], "Regular"}
      ],
      as: "segment"
    }
  ])
```

### Business Rules Implementation

```elixir
# Discount calculation
selecto
|> Selecto.select([
    "order.*",
    {:case_when, [
        {[
          {"customer.tier", "Platinum"},
          {"order.total", {:>=, 500}}
        ], "order.total * 0.20"},
        {[
          {"customer.tier", "Gold"},
          {"order.total", {:>=, 300}}
        ], "order.total * 0.15"},
        {[
          {"order.total", {:>=, 1000}}
        ], "order.total * 0.10"},
        {[
          {:exists, fn ->
            Selecto.from("promotion")
            |> Selecto.filter([{"code", {:ref, "order.promo_code"}}])
          end}
        ], "order.total * 0.05"}
      ],
      else: 0,
      as: "discount_amount"
    }
  ])
```

### Dynamic Formatting

```elixir
# Format output based on locale
selecto
|> Selecto.select([
    "product.name",
    {:case, "user.locale",
      when: [
        {"en_US", {:concat, ["'$'", "product.price"]}},
        {"en_GB", {:concat, ["'£'", "product.price * 0.79"]}},
        {"eu_EU", {:concat, ["'€'", "product.price * 0.85"]}},
        {"jp_JP", {:concat, ["'¥'", "product.price * 110"]}}
      ],
      else: {:cast, "product.price", :text},
      as: "formatted_price"
    }
  ])
```

## See Also

- [PostgreSQL CASE Documentation](https://www.postgresql.org/docs/current/functions-conditional.html)
- [Window Functions Guide](./window-functions.md)
- [Common Table Expressions Guide](./cte.md)
- [Subqueries Guide](./subqueries.md)