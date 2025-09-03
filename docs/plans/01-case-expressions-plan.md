# CASE Expressions Implementation Plan

## Overview
Implement SQL CASE expressions in Selecto to enable conditional logic in SELECT, WHERE, and ORDER BY clauses.

## API Design

### Simple CASE Expression
```elixir
# Simple CASE (comparing single field)
Selecto.select(selecto, [
  "title",
  {:case, "rating",
    when: [
      {"G", "General"},
      {"PG", "Parental Guidance"},
      {"PG-13", "Parents Cautioned"},
      {"R", "Restricted"}
    ],
    else: "Not Rated",
    as: "rating_description"
  }
])
```

### Searched CASE Expression
```elixir
# Searched CASE (multiple conditions)
Selecto.select(selecto, [
  "customer_name",
  {:case_when, [
    {[{"total_spent", {:>=, 10000}}], "Platinum"},
    {[{"total_spent", {:>=, 5000}}], "Gold"},
    {[{"total_spent", {:>=, 1000}}], "Silver"}
  ],
  else: "Bronze",
  as: "tier"}
])
```

## Implementation Steps

### Step 1: Add Public API Functions
**File**: `vendor/selecto/lib/selecto.ex`

```elixir
@doc """
Adds a CASE expression to the select clause.
"""
@spec case_select(t(), map()) :: t()
def case_select(%__MODULE__{} = selecto, case_spec) do
  field = build_case_field(case_spec)
  select(selecto, [field])
end

defp build_case_field(%{case: field, when: conditions, else: default} = spec) do
  {:case, field, spec}
end

defp build_case_field(%{case_when: conditions, else: default} = spec) do
  {:case_when, conditions, spec}
end
```

### Step 2: Create CASE Expression Builder
**File**: `vendor/selecto/lib/selecto/builder/case_expression.ex`

```elixir
defmodule Selecto.Builder.CaseExpression do
  @moduledoc """
  Builds SQL CASE expressions for conditional logic.
  """

  def build({:case, field, spec}, params, selecto) do
    build_simple_case(field, spec, params, selecto)
  end

  def build({:case_when, conditions, spec}, params, selecto) do
    build_searched_case(conditions, spec, params, selecto)
  end

  defp build_simple_case(field, %{when: conditions, else: else_value} = spec, params, selecto) do
    {field_sql, params} = build_field_reference(field, params, selecto)
    
    {when_clauses, params} = Enum.reduce(conditions, {[], params}, fn
      {value, result}, {clauses, params} ->
        {value_sql, params} = add_param(value, params)
        {result_sql, params} = add_param(result, params)
        clause = "WHEN #{value_sql} THEN #{result_sql}"
        {[clause | clauses], params}
    end)
    
    {else_sql, params} = if else_value do
      {else_sql, params} = add_param(else_value, params)
      {"ELSE #{else_sql}", params}
    else
      {"", params}
    end
    
    sql = [
      "CASE #{field_sql}",
      Enum.reverse(when_clauses),
      else_sql,
      "END"
    ] |> Enum.filter(&(&1 != "")) |> Enum.join(" ")
    
    {sql, params}
  end

  defp build_searched_case(conditions, %{else: else_value} = spec, params, selecto) do
    {when_clauses, params} = Enum.reduce(conditions, {[], params}, fn
      {condition_list, result}, {clauses, params} ->
        {condition_sql, params} = build_conditions(condition_list, params, selecto)
        {result_sql, params} = add_param(result, params)
        clause = "WHEN #{condition_sql} THEN #{result_sql}"
        {[clause | clauses], params}
    end)
    
    {else_sql, params} = if else_value do
      {else_sql, params} = add_param(else_value, params)
      {"ELSE #{else_sql}", params}
    else
      {"", params}
    end
    
    sql = [
      "CASE",
      Enum.reverse(when_clauses),
      else_sql,
      "END"
    ] |> Enum.filter(&(&1 != "")) |> Enum.join(" ")
    
    {sql, params}
  end

  defp build_conditions(conditions, params, selecto) do
    # Reuse WHERE clause builder logic
    Selecto.Builder.Sql.Where.build_condition_list(conditions, params, selecto)
  end

  defp build_field_reference(field, params, selecto) do
    Selecto.Builder.Sql.Select.prep_selector(field, params, selecto)
  end

  defp add_param(value, params) do
    params = params ++ [value]
    {"$#{length(params)}", params}
  end
end
```

### Step 3: Integrate with SQL Builder
**File**: `vendor/selecto/lib/selecto/builder/sql/select.ex`

Add handling for CASE expressions in the `prep_selector/3` function:

```elixir
defp prep_selector({:case, field, spec}, params, selecto) do
  {case_sql, params} = Selecto.Builder.CaseExpression.build({:case, field, spec}, params, selecto)
  alias_part = if spec[:as], do: " AS #{spec[:as]}", else: ""
  {case_sql <> alias_part, params}
end

defp prep_selector({:case_when, conditions, spec}, params, selecto) do
  {case_sql, params} = Selecto.Builder.CaseExpression.build({:case_when, conditions, spec}, params, selecto)
  alias_part = if spec[:as], do: " AS #{spec[:as]}", else: ""
  {case_sql <> alias_part, params}
end
```

### Step 4: Add WHERE Clause Support
**File**: `vendor/selecto/lib/selecto/builder/sql/where.ex`

```elixir
defp build_filter({:case, _, _} = case_expr, params, selecto) do
  Selecto.Builder.CaseExpression.build(case_expr, params, selecto)
end

defp build_filter({:case_when, _, _} = case_expr, params, selecto) do
  Selecto.Builder.CaseExpression.build(case_expr, params, selecto)
end
```

### Step 5: Add ORDER BY Support
**File**: `vendor/selecto/lib/selecto/builder/sql/order_by.ex`

```elixir
defp build_order_field({:case, _, _} = case_expr, direction, params, selecto) do
  {case_sql, params} = Selecto.Builder.CaseExpression.build(case_expr, params, selecto)
  {case_sql <> " " <> to_string(direction), params}
end
```

## Testing Plan

### Unit Tests
**File**: `test/selecto/builder/case_expression_test.exs`

```elixir
defmodule Selecto.Builder.CaseExpressionTest do
  use ExUnit.Case
  
  test "builds simple CASE expression" do
    spec = {:case, "rating", %{
      when: [{"G", "General"}, {"PG", "Parental"}],
      else: "Unknown"
    }}
    
    {sql, params} = Selecto.Builder.CaseExpression.build(spec, [], mock_selecto())
    
    assert sql =~ "CASE"
    assert sql =~ "WHEN $1 THEN $2"
    assert params == ["G", "General", "PG", "Parental", "Unknown"]
  end
  
  test "builds searched CASE expression" do
    spec = {:case_when, [
      {[{"amount", {:>, 100}}], "High"},
      {[{"amount", {:>, 50}}], "Medium"}
    ], %{else: "Low"}}
    
    {sql, params} = Selecto.Builder.CaseExpression.build(spec, [], mock_selecto())
    
    assert sql =~ "CASE"
    assert sql =~ "WHEN amount > $1 THEN $2"
    assert params == [100, "High", 50, "Medium", "Low"]
  end
end
```

### Integration Tests
Use the existing docs tests once implementation is complete.

## Migration Guide

For users upgrading:
1. No breaking changes to existing API
2. New functions are additive only
3. Can progressively adopt CASE expressions

## Performance Considerations

1. **Parameter Binding**: Use parameterized queries to prevent SQL injection
2. **Complex Conditions**: Nested CASE expressions should be limited for readability
3. **Index Usage**: CASE in WHERE clause may prevent index usage

## Documentation

### Public API Docs
```elixir
@doc """
Adds a CASE expression to enable conditional logic in queries.

## Simple CASE

Compares a single field against multiple values:

    iex> Selecto.select(selecto, [
    ...>   {:case, "status",
    ...>     when: [
    ...>       {"pending", "Awaiting"},
    ...>       {"active", "Running"},
    ...>       {"completed", "Done"}
    ...>     ],
    ...>     else: "Unknown",
    ...>     as: "status_label"}
    ...> ])

## Searched CASE

Evaluates multiple conditions:

    iex> Selecto.select(selecto, [
    ...>   {:case_when, [
    ...>     {[{"score", {:>=, 90}}], "A"},
    ...>     {[{"score", {:>=, 80}}], "B"},
    ...>     {[{"score", {:>=, 70}}], "C"}
    ...>   ],
    ...>   else: "F",
    ...>   as: "grade"}
    ...> ])
"""
```

## Rollout Strategy

1. **Phase 1**: Implement basic CASE in SELECT
2. **Phase 2**: Add WHERE clause support
3. **Phase 3**: Add ORDER BY support
4. **Phase 4**: Add nested CASE support

## Success Criteria

- [ ] All CASE expression tests from docs pass
- [ ] No performance regression in existing queries
- [ ] Documentation complete with examples
- [ ] Integration with SelectoComponents for UI