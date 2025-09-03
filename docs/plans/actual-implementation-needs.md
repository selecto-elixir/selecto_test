# Actual Implementation Needs for Selecto

## Overview
Based on the analysis, most features are implemented but need either:
1. API wrapper functions for better ergonomics
2. Test fixes to use correct syntax
3. Only CASE expressions need full implementation

## Priority 1: Fix Existing Tests (1-2 days)

### Task: Update all test files to use correct API
The features exist, tests just use wrong syntax.

#### Example Fixes Needed:

**Array Operations Test Fix:**
```elixir
# WRONG (current test):
selecto
|> Selecto.array_select({:array_agg, "title", as: "titles"})

# CORRECT (should be):
selecto
|> Selecto.select([{:array_agg, "title", as: "titles"}])
|> Selecto.group_by(["category"])
```

**CTE Test Fix:**
```elixir
# WRONG (current test):
selecto
|> Selecto.with_cte("active", fn -> 
    Selecto.filter([{"active", true}])
  end)

# CORRECT (should be):
selecto
|> Selecto.with_cte("active", fn _base_selecto ->
    Selecto.configure(domain, conn)
    |> Selecto.select(["*"])
    |> Selecto.from("customers")
    |> Selecto.filter([{"active", true}])
  end)
```

**Window Function Test Fix:**
```elixir
# WRONG (current test):
selecto
|> Selecto.select([
    {:row_number, over: "PARTITION BY category ORDER BY price DESC"}
  ])

# CORRECT (should be):
selecto
|> Selecto.window_function(:row_number, [], 
    partition_by: ["category"],
    order_by: [{"price", :desc}],
    as: "row_num")
|> Selecto.select(["*", "row_num"])
```

## Priority 2: Add CASE Expression Support (2-3 days)

This is the ONLY major feature that's actually missing.

### Implementation Plan:

#### Step 1: Add to Selecto module
```elixir
# vendor/selecto/lib/selecto.ex
def case_when(selecto, conditions, opts \\ []) do
  case_spec = %CaseExpression.Spec{
    type: :searched,
    conditions: conditions,
    else_value: opts[:else],
    alias: opts[:as]
  }
  
  %{selecto | 
    select_fields: selecto.select_fields ++ [{:case_when, case_spec}]
  }
end
```

#### Step 2: Create CASE builder
```elixir
# vendor/selecto/lib/selecto/builder/case_expression.ex
defmodule Selecto.Builder.CaseExpression do
  def build(%Spec{type: :simple} = spec, params) do
    # Build CASE field WHEN val1 THEN result1 END
  end
  
  def build(%Spec{type: :searched} = spec, params) do
    # Build CASE WHEN condition THEN result END
  end
end
```

#### Step 3: Integrate with SQL builder
```elixir
# vendor/selecto/lib/selecto/builder/sql/select.ex
defp prep_selector({:case_when, spec}, params, selecto) do
  CaseExpression.build(spec, params)
end
```

## Priority 3: Add Convenience Wrappers (1 day)

These features exist but could use better APIs.

### Array Operation Wrappers
```elixir
# vendor/selecto/lib/selecto.ex

def array_agg(selecto, field, opts \\ []) do
  select_field = {:array_agg, field, opts}
  select(selecto, [select_field])
end

def array_filter(selecto, array_op) do
  filter(selecto, [array_op])
end
```

### JSON Operation Wrappers
```elixir
def json_select(selecto, json_spec) do
  select(selecto, [json_spec])
end

def jsonb_filter(selecto, field, path, value) do
  filter(selecto, [{:jsonb_path, field, path, value}])
end
```

## Priority 4: Fix Domain Configurations (1 day)

Update test helpers to properly configure domains with joins.

```elixir
# test/support/test_helpers.ex
def get_test_domain(table_name) do
  %{
    source: get_source_for_table(table_name),
    schemas: get_all_related_schemas(table_name),
    joins: get_configured_joins(table_name),  # Add this
    settings: %{validate: false}
  }
end

defp get_configured_joins("film") do
  %{
    "category" => %{
      type: :inner,
      through: "film_category",
      on: "film.film_id = film_category.film_id AND film_category.category_id = category.category_id"
    },
    "actor" => %{
      type: :inner,
      through: "film_actor",
      on: "film.film_id = film_actor.film_id AND film_actor.actor_id = actor.actor_id"
    }
  }
end
```

## Total Timeline: 5-7 days

### Day 1-2: Fix Tests
- Update test syntax to use actual API
- Run tests to verify features work

### Day 3-4: Implement CASE Expressions
- Add CASE/WHEN support
- Test with documentation examples

### Day 5: Add Convenience Wrappers
- Array operation helpers
- JSON operation helpers

### Day 6-7: Polish & Documentation
- Fix domain configurations
- Update documentation with correct examples
- Ensure all tests pass

## Success Metrics
- [ ] All 184 tests passing
- [ ] CASE expressions working
- [ ] Documentation matches actual API
- [ ] No breaking changes to existing code

## Next Steps
1. Start by fixing a few test files to confirm approach
2. Implement CASE expressions (only missing feature)
3. Add convenience wrappers for better ergonomics
4. Update documentation with working examples