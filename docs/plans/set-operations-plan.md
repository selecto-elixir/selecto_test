# Set Operations Enhancement Plan

## Overview

Add comprehensive set operation support (UNION, INTERSECT, EXCEPT) to Selecto for combining and comparing query results from multiple sources.

## Architecture Design

### Core Module Structure
```
vendor/selecto/lib/selecto/set_operations.ex           # Main set operations API
vendor/selecto/lib/selecto/builder/set_operations.ex   # SQL generation
vendor/selecto/lib/selecto/set_operations/             # Operation-specific modules
├── union.ex                                           # UNION and UNION ALL
├── intersect.ex                                       # INTERSECT operations
├── except.ex                                          # EXCEPT operations  
└── validation.ex                                      # Schema compatibility validation
```

### API Design

#### Basic Set Operations
```elixir
# UNION - combine results from multiple queries
query1 = Selecto.configure(domain1, connection)
  |> Selecto.select(["name", "email"])
  |> Selecto.filter([{"status", "active"}])

query2 = Selecto.configure(domain2, connection)  
  |> Selecto.select(["full_name", "email_address"])
  |> Selecto.filter([{"active", true}])

combined = Selecto.union(query1, query2, all: true)
```

#### Advanced Set Operations
```elixir
# INTERSECT - find common records
common_users = Selecto.intersect(
  active_users_query,
  premium_users_query
)

# EXCEPT - find differences  
free_users = Selecto.except(
  all_users_query,
  premium_users_query
)

# Chained operations
result = query1
  |> Selecto.union(query2) 
  |> Selecto.intersect(query3)
  |> Selecto.except(query4)
```

#### Set Operations with Different Schemas
```elixir
# Automatic column mapping and type coercion
customers = Selecto.configure(customer_domain, connection)
  |> Selecto.select(["name", "email", {:literal, "customer"}, "type"])

vendors = Selecto.configure(vendor_domain, connection)
  |> Selecto.select(["company_name", "contact_email", {:literal, "vendor"}, "category"])

# Union with column mapping
all_contacts = Selecto.union(customers, vendors, 
  column_mapping: [
    {"name", "company_name"},
    {"email", "contact_email"}, 
    {"type", "category"}
  ]
)
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Create `Selecto.SetOperations` API module
- [ ] Basic UNION and UNION ALL support
- [ ] Schema compatibility validation
- [ ] Integration with query execution pipeline

### Phase 2: Core Operations (Week 3-4)
- [ ] Implement INTERSECT and INTERSECT ALL
- [ ] Add EXCEPT and EXCEPT ALL operations  
- [ ] Column mapping and type coercion
- [ ] ORDER BY support for set operations

### Phase 3: Advanced Features (Week 5-6)
- [ ] Chained set operations with proper precedence
- [ ] Nested set operations with parentheses
- [ ] Set operations with CTEs and subqueries
- [ ] Performance optimization for large set operations

### Phase 4: Integration & Polish (Week 7-8)
- [ ] Integration with existing Selecto features (joins, filters, etc.)
- [ ] SelectoComponents integration for set operation UI
- [ ] Comprehensive testing and documentation
- [ ] Performance benchmarking

## SQL Generation Examples

### Simple UNION
```elixir
# Input
query1 |> Selecto.union(query2, all: true)
```

```sql
-- Generated SQL
(SELECT name, email FROM customers WHERE status = 'active')
UNION ALL
(SELECT full_name, email_address FROM vendors WHERE active = true)
```

### Complex Set Operations with ORDER BY
```elixir
# Input  
query1
|> Selecto.union(query2)
|> Selecto.intersect(query3)
|> Selecto.order_by([{"name", :asc}])
```

```sql
-- Generated SQL
(
  (SELECT name, email FROM customers WHERE status = 'active')
  UNION 
  (SELECT full_name, email_address FROM vendors WHERE active = true)
)
INTERSECT
(SELECT name, email FROM premium_users)
ORDER BY name ASC
```

## Set Operation Types

### UNION Operations
- **UNION**: Remove duplicates from combined results
- **UNION ALL**: Include all rows, including duplicates
- **Performance**: UNION ALL is faster as it skips duplicate elimination

### INTERSECT Operations  
- **INTERSECT**: Return only rows that appear in both queries
- **INTERSECT ALL**: Include duplicate intersecting rows
- **Use cases**: Finding common customers, overlapping data analysis

### EXCEPT Operations
- **EXCEPT**: Return rows from first query not in second query  
- **EXCEPT ALL**: Include duplicates in difference calculation
- **Use cases**: Finding unique records, data reconciliation

## Schema Compatibility

### Automatic Column Mapping
```elixir
# Define column mappings for incompatible schemas
mapping = [
  {"customer_name", "vendor_name"},       # String to String
  {"created_at", "registration_date"},    # DateTime to DateTime
  {"total_spent", "contract_value"}       # Numeric to Numeric
]

Selecto.union(query1, query2, column_mapping: mapping)
```

### Type Coercion Rules
- **String types**: VARCHAR, TEXT, CHAR automatically compatible
- **Numeric types**: INTEGER, DECIMAL, FLOAT with automatic casting
- **Date/Time**: DATE, TIMESTAMP, TIMESTAMPTZ with timezone handling
- **Boolean**: BOOLEAN with true/false normalization

### Validation Strategy
- Pre-execution schema validation
- Type compatibility checking  
- Column count verification
- Clear error messages for incompatible schemas

## Integration Points

### With Existing Selecto Features
- **Joins**: Set operations on joined query results
- **Filters**: WHERE clauses applied to individual queries before set operation
- **Pivot/Subselect**: Set operations on pivot/subselect results
- **Window Functions**: Window functions applied after set operations

### With SelectoComponents
```elixir
# UI controls for set operations
%{
  type: :set_operation,
  operation: :union,
  queries: [query1_config, query2_config],
  options: %{
    all: true,
    column_mapping: mapping
  }
}
```

## Testing Strategy

### Unit Tests
```elixir
test "UNION generates correct SQL" do
  result = Selecto.union(query1, query2, all: true)
    |> Selecto.to_sql()
    
  assert result =~ "UNION ALL"
  assert result =~ "(SELECT"
end

test "validates schema compatibility" do
  incompatible_query2 = query_with_different_columns()
  
  assert_raise Selecto.SetOperations.SchemaError, fn ->
    Selecto.union(query1, incompatible_query2)
  end
end
```

### Integration Tests  
- Set operations with complex joins
- Performance testing with large datasets
- Cross-domain set operations
- Set operations in SelectoComponents

## Performance Considerations

### Query Optimization
- **Index usage**: Ensure proper indexes on columns used in set operations
- **Sort optimization**: Minimize sorting overhead for UNION operations  
- **Memory management**: Handle large result sets efficiently
- **Parallel execution**: Support for parallel set operation execution

### Best Practices
- Use UNION ALL when duplicates are acceptable (faster)
- Apply filters before set operations to reduce data volume
- Consider materialized views for frequently used set operations
- Monitor query execution plans for set operation optimization

## Error Handling

### Schema Validation Errors
```elixir
# Clear error messages for common issues
%Selecto.SetOperations.SchemaError{
  type: :column_count_mismatch,
  message: "Query 1 has 3 columns, Query 2 has 4 columns",
  query1_columns: ["name", "email", "status"],
  query2_columns: ["name", "email", "phone", "status"]
}
```

### Runtime Errors
- Database connection failures during set operations
- Memory overflow on large set operations  
- Type conversion errors with incompatible data

## Documentation Requirements

- [ ] Complete API documentation for all set operations
- [ ] Schema compatibility guide and examples
- [ ] Performance tuning recommendations
- [ ] Common use case examples and patterns
- [ ] Migration guide from manual UNION queries

## Migration Path

### From Raw SQL
```elixir
# Before: Raw SQL UNION
selecto |> Selecto.select([{:raw, "(SELECT ... UNION SELECT ...)"}])

# After: Native Selecto API
query1 |> Selecto.union(query2)
```

### From Manual Result Combination
```elixir  
# Before: Manual result merging in application code
results1 = Selecto.execute!(query1)
results2 = Selecto.execute!(query2)  
combined = merge_results(results1, results2)

# After: Database-level set operations
combined = query1 |> Selecto.union(query2) |> Selecto.execute!()
```

## Success Metrics

- [ ] All PostgreSQL set operations supported (UNION, INTERSECT, EXCEPT)
- [ ] Automatic schema compatibility detection and mapping
- [ ] Performance within 10% of hand-written SQL
- [ ] Zero breaking changes to existing functionality  
- [ ] Comprehensive test coverage (>95%)
- [ ] Clear error messages for all failure scenarios