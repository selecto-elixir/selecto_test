# Fix Documentation Examples Plan

## Overview
The documentation in `docs/advanced-features/` contains example code that doesn't match the actual Selecto API. This plan outlines how to fix each documentation file to show the correct, working API.

## Files to Fix

### 1. `docs/advanced-features/array-operations.md`

**Current (Wrong):**
```elixir
selecto
|> Selecto.array_select({:array_agg, "film.title", as: "film_titles"})
|> Selecto.array_filter({:array_contains, "tags", ["action", "drama"]})
```

**Fixed (Correct):**
```elixir
# Array aggregation in SELECT
selecto
|> Selecto.select([
    "category",
    {:array_agg, "film.title", as: "film_titles"}
  ])
|> Selecto.group_by(["category"])

# Array filtering in WHERE
selecto
|> Selecto.filter([
    {:array_contains, "tags", ["action", "drama"]}
  ])
```

### 2. `docs/advanced-features/cte.md`

**Current (Wrong):**
```elixir
selecto
|> Selecto.with_cte("active_customers", fn ->
    Selecto.filter([{"active", true}])
  end)
```

**Fixed (Correct):**
```elixir
selecto
|> Selecto.with_cte("active_customers", fn base_selecto ->
    base_selecto
    |> Selecto.select(["*"])
    |> Selecto.from("customers")
    |> Selecto.filter([{"active", true}])
  end)
|> Selecto.select(["*"])
|> Selecto.from("active_customers")

# Or for recursive CTEs:
selecto
|> Selecto.with_recursive_cte("category_tree", %{
    base_query: fn ->
      Selecto.configure(domain, conn)
      |> Selecto.select(["id", "name", "parent_id", "0 AS level"])
      |> Selecto.from("categories")
      |> Selecto.filter([{"parent_id", nil}])
    end,
    recursive_query: fn cte_name ->
      Selecto.configure(domain, conn)
      |> Selecto.select([
          "c.id",
          "c.name",
          "c.parent_id",
          "ct.level + 1 AS level"
        ])
      |> Selecto.from("categories AS c")
      |> Selecto.join(:inner, "#{cte_name} AS ct", on: "c.parent_id = ct.id")
    end
  })
```

### 3. `docs/advanced-features/window-functions.md`

**Current (Wrong):**
```elixir
selecto
|> Selecto.select([
    {:row_number, over: "PARTITION BY category ORDER BY price DESC", as: "rank"}
  ])
```

**Fixed (Correct):**
```elixir
# Add window function first, then select it
selecto
|> Selecto.window_function(:row_number, [], %{
    partition_by: ["category"],
    order_by: [{"price", :desc}],
    as: "rank"
  })
|> Selecto.select(["product_name", "category", "price", "rank"])

# Or for aggregate window functions:
selecto
|> Selecto.window_function(:sum, ["amount"], %{
    order_by: [{"date", :asc}],
    frame: {:rows, :unbounded_preceding, :current_row},
    as: "running_total"
  })
|> Selecto.select(["date", "amount", "running_total"])
```

### 4. `docs/advanced-features/lateral-joins.md`

**Current (Wrong):**
```elixir
selecto
|> Selecto.lateral_join(:left, fn base ->
    Selecto.select(["*"])
    |> Selecto.filter([{"customer_id", {:ref, "c.id"}}])
  end, as: "recent_orders")
```

**Fixed (Correct):**
```elixir
selecto
|> Selecto.lateral_join(:left, fn base_selecto ->
    Selecto.configure(domain, conn)
    |> Selecto.select(["order_id", "order_date", "total"])
    |> Selecto.from("orders")
    |> Selecto.filter([{"customer_id", {:ref, "customers.id"}}])
    |> Selecto.order_by([{"order_date", :desc}])
    |> Selecto.limit(5)
  end, "recent_orders", [])
|> Selecto.select(["customers.*", "recent_orders.*"])
```

### 5. `docs/advanced-features/set-operations.md`

**Current (Wrong):**
```elixir
selecto
|> Selecto.union(
    Selecto.select(["name", "email"])
    |> Selecto.from("contractors")
  )
```

**Fixed (Correct):**
```elixir
# Create two separate queries first
employees_query = 
  Selecto.configure(employee_domain, conn)
  |> Selecto.select(["name", "email", "'Employee' AS type"])
  |> Selecto.filter([{"active", true}])

contractors_query = 
  Selecto.configure(contractor_domain, conn)
  |> Selecto.select(["name", "email", "'Contractor' AS type"])
  |> Selecto.filter([{"active", true}])

# Then combine with set operation
result = Selecto.union(employees_query, contractors_query)

# For UNION ALL:
result = Selecto.union(employees_query, contractors_query, all: true)
```

### 6. `docs/advanced-features/subselects.md`

**Current (Wrong):**
```elixir
selecto
|> Selecto.subselect(["order[product_name, quantity]"])
```

**Fixed (Correct):**
```elixir
selecto
|> Selecto.subselect([
    %{
      fields: ["product_name", "quantity", "price"],
      target_schema: :order_items,
      format: :json_agg,
      alias: "items",
      filter: [{"order_id", {:ref, "orders.id"}}],
      order_by: [{"line_number", :asc}]
    }
  ])
|> Selecto.select(["orders.id", "orders.customer_id", "orders.total"])
```

### 7. `docs/advanced-features/case-expressions.md`

**Note:** CASE expressions are NOT implemented yet. Mark as "Coming Soon" or implement first.

**Proposed API (if implementing):**
```elixir
# Simple CASE
selecto
|> Selecto.select([
    "title",
    {:case, "rating", [
      {"G", "General"},
      {"PG", "Parental Guidance"},
      {"R", "Restricted"}
    ], else: "Not Rated", as: "rating_label"}
  ])

# Searched CASE (needs implementation)
selecto
|> Selecto.select([
    "customer_name",
    {:case_when, [
      {[{"total_spent", {:>=, 10000}}], "Platinum"},
      {[{"total_spent", {:>=, 5000}}], "Gold"}
    ], else: "Bronze", as: "tier"}
  ])
```

### 8. `docs/advanced-features/json-operations.md`

**Current (Wrong):**
```elixir
selecto
|> Selecto.json_select({:json_get, "metadata", "$.user.name", as: "user_name"})
```

**Fixed (Correct):**
```elixir
# JSON operations in SELECT
selecto
|> Selecto.select([
    "id",
    {:json_get, "metadata", "user.name", as: "user_name"},
    {:jsonb_path_query, "data", "$.items[*].price", as: "prices"}
  ])

# JSON operations in WHERE
selecto
|> Selecto.filter([
    {:jsonb_contains, "metadata", %{"active" => true}},
    {:jsonb_path_exists, "data", "$.items[?(@.price > 100)]"}
  ])
```

### 9. `docs/advanced-features/subqueries-subfilters.md`

**Current (Shows concept, needs actual API):**
```elixir
selecto
|> Selecto.filter([
    {:exists, fn ->
      Selecto.from("orders")
      |> Selecto.filter([{"customer_id", {:ref, "customers.id"}}])
    end}
  ])
```

**Fixed (Correct - if this API exists):**
```elixir
# EXISTS subquery
selecto
|> Selecto.filter([
    {:exists, fn ->
      Selecto.configure(order_domain, conn)
      |> Selecto.select(["1"])
      |> Selecto.from("orders")
      |> Selecto.filter([
          {"customer_id", {:ref, "customers.id"}},
          {"status", "completed"}
        ])
      |> Selecto.limit(1)
    end}
  ])

# IN subquery
selecto
|> Selecto.filter([
    {"id", {:in, fn ->
      Selecto.configure(order_domain, conn)
      |> Selecto.select(["DISTINCT customer_id"])
      |> Selecto.from("orders")
      |> Selecto.filter([{"total", {:>, 1000}}])
    end}}
  ])
```

## Implementation Strategy

### Phase 1: Update Documentation (2-3 days)
1. Fix all example code to use actual Selecto API
2. Add notes where features aren't implemented
3. Include complete, runnable examples
4. Add "Prerequisites" section showing domain setup

### Phase 2: Create Working Examples (2 days)
1. Create `examples/` directory with runnable code
2. One file per feature showing real usage
3. Include domain configuration setup
4. Add to CI to ensure examples keep working

### Phase 3: Add Migration Guide (1 day)
Create `docs/migration-from-docs.md` showing:
- Old (documentation) syntax
- New (actual) syntax
- Explanation of differences
- Common pitfalls

## Documentation Template

Each documentation file should follow this structure:

```markdown
# Feature Name

## Prerequisites
```elixir
# Domain configuration required
domain = %{
  source: %{...},
  schemas: %{...},
  joins: %{...}
}

selecto = Selecto.configure(domain, conn)
```

## Basic Usage
[Working examples with actual API]

## Advanced Usage
[More complex examples]

## Common Patterns
[Typical use cases]

## Troubleshooting
[Common errors and solutions]

## See Also
[Links to related features]
```

## Success Criteria
- [ ] All documentation examples compile without errors
- [ ] All documentation examples produce correct SQL
- [ ] Examples are tested in CI
- [ ] Clear distinction between implemented and planned features
- [ ] Migration guide helps users transition from old docs

## Notes
- Mark unimplemented features clearly as "Planned" or "Coming Soon"
- Include SQL output for each example to show what's generated
- Add performance considerations where relevant
- Link to test files that demonstrate usage