# Selecto Feature Analysis - What's Actually Implemented

## Summary
After analyzing the codebase, most of the advanced features documented ARE actually implemented in Selecto. The test failures are occurring because:
1. The test files use incorrect API syntax
2. The domain configurations in tests are incomplete
3. Some function names in tests don't match the actual API

## Implemented Features ✅

### 1. CTEs (Common Table Expressions)
- **Implemented Functions:**
  - `Selecto.with_cte/3` - Basic CTEs
  - `Selecto.with_recursive_cte/3` - Recursive CTEs
  - `Selecto.with_ctes/2` - Multiple CTEs
- **Files:** 
  - `vendor/selecto/lib/selecto/advanced/cte.ex`
  - `vendor/selecto/lib/selecto/builder/cte.ex`

### 2. Window Functions
- **Implemented Functions:**
  - `Selecto.window_function/4` - General window function support
- **Files:**
  - `vendor/selecto/lib/selecto/window.ex`
  - `vendor/selecto/lib/selecto/builder/window.ex`

### 3. LATERAL Joins
- **Implemented Functions:**
  - `Selecto.lateral_join/5` - LATERAL join support
- **Files:**
  - `vendor/selecto/lib/selecto/advanced/lateral_join.ex`
  - `vendor/selecto/lib/selecto/builder/lateral_join.ex`

### 4. Set Operations
- **Implemented Functions:**
  - `Selecto.union/3` - UNION and UNION ALL
  - `Selecto.intersect/3` - INTERSECT and INTERSECT ALL
  - `Selecto.except/3` - EXCEPT and EXCEPT ALL
- **Files:**
  - `vendor/selecto/lib/selecto/set_operations.ex`
  - `vendor/selecto/lib/selecto/builder/set_operations.ex`

### 5. Subselects
- **Implemented Functions:**
  - `Selecto.subselect/3` - Nested data aggregation
- **Files:**
  - `vendor/selecto/lib/selecto/subselect.ex`
  - `vendor/selecto/lib/selecto/builder/subselect.ex`

### 6. Array Operations (Partial)
- **Some Support Exists:**
  - Array aggregation building in `vendor/selecto/lib/selecto/builder/array_operations.ex`
  - But missing public API functions like `array_select`, `array_filter`

### 7. JSON Operations (Partial)
- **Some Support Exists:**
  - JSON building in SQL functions
  - But missing dedicated public API

## Missing or Incomplete Features ❌

### 1. Array Operations API
**Missing Functions:**
- `Selecto.array_select/2` - Not implemented
- `Selecto.array_filter/2` - Not implemented
- Need to add these as wrappers around existing builder functionality

### 2. CASE Expressions
**Missing Functions:**
- `Selecto.case_select/2` - Not implemented
- No CASE expression builder
- This is a genuinely missing feature

### 3. Simplified Subquery API
**Missing Functions:**
- Direct subquery support in filters (EXISTS, IN with subqueries)
- Need helper functions for common patterns

## Test Failures Root Causes

### 1. Incorrect API Usage in Tests
```elixir
# Test tries to use (WRONG):
Selecto.array_select(selecto, {:array_agg, "title", as: "titles"})

# Should use (CORRECT):
Selecto.select(selecto, [{:array_agg, "title", as: "titles"}])
```

### 2. Domain Configuration Issues
```elixir
# Test tries to access:
"category.name"  # But no join is configured

# Need proper join setup:
selecto |> Selecto.join(:inner, "category", on: "...")
```

### 3. Function Name Mismatches
```elixir
# Tests use non-existent functions:
- array_select (should be part of select)
- array_filter (should be part of filter)
- case_select (should be part of select)
```

## Recommendations

### Immediate Actions
1. **Fix test files** to use correct Selecto API
2. **Update domain configurations** in tests to include necessary joins
3. **Add helper functions** for commonly used patterns

### Short-term Improvements
1. **Add CASE expression support** - This is genuinely missing
2. **Add array operation helpers** - Wrap existing functionality
3. **Add JSON operation helpers** - Wrap existing functionality

### Documentation Updates
1. Update docs to show actual API usage
2. Add migration guide from documentation examples to real API
3. Create cookbook with working examples

## Corrected API Examples

### CTE (Working)
```elixir
selecto
|> Selecto.with_cte("active_customers", fn ->
    Selecto.filter([{"active", true}])
  end)
|> Selecto.select(["*"])
|> Selecto.from("active_customers")
```

### Window Function (Working)
```elixir
selecto
|> Selecto.window_function(:row_number, [], 
    partition_by: ["category"],
    order_by: [{"price", :desc}])
```

### LATERAL Join (Working)
```elixir
selecto
|> Selecto.lateral_join(:left, fn base ->
    Selecto.select(["*"])
    |> Selecto.filter([{"customer_id", {:ref, "c.id"}}])
    |> Selecto.limit(5)
  end, "recent_orders")
```

### Set Operations (Working)
```elixir
query1 = selecto |> Selecto.select(["id", "name"])
query2 = other_selecto |> Selecto.select(["id", "name"])

Selecto.union(query1, query2)
```

### Array Operations (Needs Wrapper)
```elixir
# Currently must use:
selecto |> Selecto.select([{:array_agg, "title", as: "titles"}])

# Could add helper:
selecto |> Selecto.array_select({:array_agg, "title", as: "titles"})
```

### CASE Expressions (Not Implemented)
```elixir
# Needs implementation
selecto |> Selecto.select([
  {:case, "rating",
    when: [{"G", "General"}, {"PG", "Parental"}],
    else: "Unknown"}
])
```