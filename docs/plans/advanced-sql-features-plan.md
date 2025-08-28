# Advanced SQL Features Enhancement Plan

## Overview

Add support for advanced PostgreSQL features including LATERAL JOINs, VALUES clauses, table functions, and enhanced JSON/JSONB operations to extend Selecto's query capabilities.

## Architecture Design

### Core Module Structure
```
vendor/selecto/lib/selecto/advanced/               # Advanced features namespace
├── lateral.ex                                     # LATERAL JOIN support
├── values.ex                                      # VALUES clause generation
├── table_functions.ex                             # PostgreSQL table functions
├── json_operations.ex                             # Enhanced JSON/JSONB support
└── common_table_expressions.ex                    # Advanced CTE patterns
vendor/selecto/lib/selecto/builder/advanced.ex     # SQL generation for advanced features
```

### API Design

#### LATERAL JOINs
```elixir
# Correlated subqueries with LATERAL
selecto
|> Selecto.select(["customers.name", "recent_orders.order_date", "recent_orders.total"])
|> Selecto.lateral_join(:recent_orders, fn parent_selecto ->
     Selecto.configure(order_domain, connection)
     |> Selecto.select(["order_date", "total"])
     |> Selecto.filter([{"customer_id", {:ref, "customers.id"}}])
     |> Selecto.order_by([{"order_date", :desc}])
     |> Selecto.limit(5)
   end)

# LATERAL with array unnesting
selecto  
|> Selecto.lateral_join(:expanded_tags, fn _parent ->
     {:unnest, "customers.tags"}  # unnest(customers.tags) AS expanded_tags
   end)
|> Selecto.select(["customers.name", "expanded_tags.value"])
```

#### VALUES Clauses
```elixir
# Inline data generation
selecto
|> Selecto.values([
     %{month: 1, name: "January", days: 31},
     %{month: 2, name: "February", days: 28},
     %{month: 3, name: "March", days: 31}
   ], as: :months)
|> Selecto.select(["months.name", "months.days"])

# VALUES with JOINs for lookup tables
selecto
|> Selecto.join_values([
     {"premium", 100},
     {"standard", 50}, 
     {"basic", 10}
   ], as: :tier_limits, on: [{"customers.tier", "tier_limits.tier"}])
|> Selecto.select(["customers.name", "tier_limits.limit"])
```

#### Table Functions
```elixir
# PostgreSQL table functions
selecto
|> Selecto.table_function(:generate_series, [1, 100], as: :numbers)
|> Selecto.select(["numbers.value"])

# Custom table functions with parameters
selecto
|> Selecto.table_function(:get_sales_by_region, ["North America", "2023"], as: :regional_sales)
|> Selecto.select(["regional_sales.month", "regional_sales.total"])

# JSON table functions
selecto
|> Selecto.table_function(:json_array_elements, ["customer_data.preferences"], as: :prefs)
|> Selecto.select(["customers.name", "prefs.value"])
```

#### Enhanced JSON Operations
```elixir
# JSON path queries
selecto
|> Selecto.select([
     "customers.name",
     {:json_path, "customer_data.profile", "$.address.city", as: "city"},
     {:json_path, "customer_data.preferences", "$[*].category", as: "categories"}
   ])

# JSON aggregation
selecto  
|> Selecto.select([
     "region",
     {:json_agg, "customer_data.profile", as: "customer_profiles"},
     {:json_object_agg, ["customers.name", "customers.total_sales"], as: "sales_by_customer"}
   ])
|> Selecto.group_by(["region"])

# JSONB operations
selecto
|> Selecto.filter([
     {:jsonb_contains, "customer_data.preferences", %{newsletter: true}},
     {:jsonb_path_exists, "customer_data.profile", "$.address.city"}
   ])
```

## Implementation Phases

### Phase 1: LATERAL JOINs (Week 1-3)
- [ ] Basic LATERAL JOIN syntax support
- [ ] Correlated subquery parameter passing
- [ ] Integration with existing JOIN infrastructure  
- [ ] LATERAL with table functions and unnest operations

### Phase 2: VALUES and Table Functions (Week 4-5)
- [ ] VALUES clause generation and integration
- [ ] Built-in PostgreSQL table function support  
- [ ] Custom table function registration system
- [ ] Parameter binding for table functions

### Phase 3: Enhanced JSON Support (Week 6-7)
- [ ] JSON path query operators (`->`, `->>`, `#>`, `#>>`)
- [ ] JSON aggregation functions (`json_agg`, `json_object_agg`)
- [ ] JSONB containment and existence operators
- [ ] JSON table functions (`json_array_elements`, `json_each`)

### Phase 4: Advanced CTEs and Integration (Week 8-9)
- [ ] Recursive CTE enhancements  
- [ ] Multiple CTE support with dependencies
- [ ] Integration testing across all advanced features
- [ ] Performance optimization and query plan analysis

## SQL Generation Examples

### LATERAL JOIN with Correlated Subquery
```elixir
# Input Selecto query
selecto
|> Selecto.lateral_join(:top_orders, fn _parent ->
     Selecto.configure(order_domain, connection)
     |> Selecto.select(["order_date", "total"])
     |> Selecto.filter([{"customer_id", {:ref, "customers.id"}}])
     |> Selecto.limit(3)
   end)
```

```sql
-- Generated SQL
SELECT customers.name, top_orders.order_date, top_orders.total
FROM customers
LEFT JOIN LATERAL (
  SELECT order_date, total 
  FROM orders 
  WHERE customer_id = customers.id 
  LIMIT 3
) top_orders ON true
```

### VALUES with Complex Data
```elixir
# Input Selecto query
selecto
|> Selecto.values([
     %{code: "USD", rate: 1.0, symbol: "$"},
     %{code: "EUR", rate: 0.85, symbol: "€"}  
   ], as: :currencies)
```

```sql
-- Generated SQL  
SELECT * FROM (
  VALUES 
    ('USD', 1.0, '$'),
    ('EUR', 0.85, '€')
) AS currencies(code, rate, symbol)
```

### Enhanced JSON Operations
```elixir
# Input Selecto query
selecto
|> Selecto.select([
     "name",
     {:json_path, "profile", "$.address.city", as: "city"},
     {:jsonb_contains, "preferences", %{newsletter: true}, as: "subscribed"}
   ])
```

```sql
-- Generated SQL
SELECT 
  name,
  profile #>> '{address,city}' AS city,
  (preferences @> '{"newsletter": true}') AS subscribed
FROM customers
```

## Integration Points

### With Existing Features
- **Regular JOINs**: LATERAL JOINs work alongside standard JOIN types
- **Filters**: WHERE clauses can reference LATERAL JOIN results
- **Window Functions**: Window functions over LATERAL JOIN results
- **Set Operations**: UNION/INTERSECT with advanced SQL features

### With SelectoComponents
- **Dynamic Data**: VALUES clauses for UI-generated lookup data
- **JSON Visualization**: Enhanced JSON operations for rich data display
- **Advanced Filters**: JSON path filtering in component interfaces

## LATERAL JOIN Patterns

### Correlated Subqueries
```elixir
# Top N per group using LATERAL
customers_with_recent_orders = selecto
  |> Selecto.lateral_join(:recent_orders, fn _parent ->
       order_selecto
       |> Selecto.filter([{"customer_id", {:ref, "customers.id"}}])
       |> Selecto.order_by([{"order_date", :desc}])
       |> Selecto.limit(5)
     end)
```

### Array Operations
```elixir
# Unnest arrays with LATERAL
selecto
|> Selecto.lateral_join(:tag_elements, {:unnest, "customers.tags"})
|> Selecto.filter([{"tag_elements.value", {:ilike, "%premium%"}}])
```

### Function Calls
```elixir  
# Table functions with LATERAL
selecto
|> Selecto.lateral_join(:monthly_stats, 
     {:table_function, :get_customer_stats, ["customers.id", "2023"]})
```

## JSON/JSONB Operation Types

### Path Operations
- `->`: JSON object field by key
- `->>`: JSON object field as text  
- `#>`: JSON object at path
- `#>>`: JSON object at path as text

### Containment Operations
- `@>`: JSON contains (left contains right)
- `<@`: JSON contained by (left contained by right)
- `?`: JSON object has key
- `?|`: JSON object has any key
- `?&`: JSON object has all keys

### Aggregation Functions
- `json_agg()`: Aggregate values as JSON array
- `json_object_agg()`: Aggregate key-value pairs as JSON object
- `jsonb_agg()`: JSONB version of json_agg
- `jsonb_object_agg()`: JSONB version of json_object_agg

## Table Function Registry

### Built-in Functions
```elixir
# Pre-registered PostgreSQL functions
table_functions = %{
  generate_series: %{params: [:integer, :integer], returns: :setof_integer},
  unnest: %{params: [:array], returns: :setof_element},
  json_array_elements: %{params: [:json], returns: :setof_json},
  json_each: %{params: [:json], returns: :setof_record}
}
```

### Custom Function Registration
```elixir
# Register custom table functions
Selecto.register_table_function(:get_sales_by_region, %{
  params: [:text, :text], 
  returns: [month: :date, total: :numeric],
  description: "Get sales data for specific region and year"
})
```

## Testing Strategy

### Unit Tests
```elixir
test "LATERAL JOIN generates correct SQL" do
  result = selecto
    |> Selecto.lateral_join(:sub, fn _p -> simple_query end)
    |> Selecto.to_sql()
    
  assert result =~ "LEFT JOIN LATERAL"
  assert result =~ "ON true"
end

test "VALUES clause with complex data" do
  values_data = [%{id: 1, name: "test"}]
  
  result = selecto
    |> Selecto.values(values_data, as: :lookup)
    |> Selecto.to_sql()
    
  assert result =~ "VALUES"
  assert result =~ "AS lookup"
end

test "JSON path operations" do
  result = selecto
    |> Selecto.select([{:json_path, "data", "$.key", as: "value"}])
    |> Selecto.to_sql()
    
  assert result =~ "#>>"
end
```

### Integration Tests
- LATERAL JOINs with complex domain relationships
- VALUES clauses in production-like scenarios  
- JSON operations with real-world data structures
- Performance testing with large datasets

## Performance Considerations

### LATERAL JOIN Optimization
- **Index usage**: Ensure correlated columns are indexed
- **Limit early**: Apply LIMIT in LATERAL subqueries when possible
- **Join selectivity**: Most selective tables joined first

### JSON Operation Performance  
- **GIN indexes**: Use GIN indexes for JSONB containment queries
- **Path indexing**: Index commonly queried JSON paths
- **Type consistency**: Use JSONB over JSON for better performance

### VALUES Clause Efficiency
- **Size limits**: Avoid very large VALUES clauses (use temp tables instead)
- **Type consistency**: Ensure consistent types across VALUES rows
- **Index compatibility**: VALUES data compatible with existing indexes

## Error Handling

### LATERAL JOIN Errors
```elixir
%Selecto.Advanced.LateralError{
  type: :invalid_correlation,
  message: "Cannot reference parent table field 'invalid_field'",
  available_fields: ["id", "name", "email"]
}
```

### JSON Operation Errors
```elixir
%Selecto.Advanced.JsonError{
  type: :invalid_path,
  message: "JSON path '$.invalid..path' is malformed",
  suggestion: "Use valid JSON path syntax like '$.field.subfield'"
}
```

## Documentation Requirements

- [ ] Complete API documentation for all advanced features
- [ ] LATERAL JOIN patterns and best practices guide
- [ ] JSON/JSONB operation reference with examples
- [ ] Table function registration and usage guide  
- [ ] Performance tuning recommendations for advanced features

## Success Metrics

- [ ] All major PostgreSQL advanced features supported
- [ ] Seamless integration with existing Selecto functionality
- [ ] Performance comparable to hand-written SQL (<15% overhead)
- [ ] Comprehensive test coverage (>95%)
- [ ] Clear documentation with practical examples