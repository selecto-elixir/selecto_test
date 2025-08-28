# Pagila Domain Fields Reference

This document provides a complete reference for all fields available in the 
pagila domain, including types, descriptions, and usage examples.

## Primary Source Fields

The following fields are available from the main `pagila` table:

### id

- **Type**: `integer`
- **Description**: Unique identifier for the record
- **Example: `42`, `1000`


### name

- **Type**: `string`
- **Description**: Display name or title
- **Example: `"Sample Name"`, `"Category A"`


### created_at

- **Type**: `datetime`
- **Description**: Timestamp when the record was created
- **Example: `~U[2024-01-15 10:30:00Z]`


### updated_at

- **Type**: `datetime`
- **Description**: Timestamp when the record was last updated
- **Example: `~U[2024-01-15 10:30:00Z]`



## Field Usage Examples

### Basic Field Selection
```elixir
# Select specific fields
Selecto.select(pagila_domain(), [:id, :name])

# Select all fields
Selecto.select(pagila_domain(), :all)
```

### Field Filtering
```elixir
# String field filtering
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.filter(:name, :like, "%example%")

# Numeric field filtering
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.filter(:id, :gt, 100)

# Date field filtering
Selecto.select(pagila_domain(), [:id, :created_at])
|> Selecto.filter(:created_at, :gt, ~D[2024-01-01])
```

### Field Aggregations
```elixir
# Count distinct values
Selecto.select(pagila_domain(), [:name, :count])
|> Selecto.group_by([:name])
|> Selecto.aggregate(:count, :id)

# Calculate averages (numeric fields only)
Selecto.select(pagila_domain(), [:avg_value])
|> Selecto.aggregate(:avg, :numeric_field)
```

## Field Type Reference

### String Fields
String fields support the following operations:
- Equality: `:eq`, `:ne`
- Pattern matching: `:like`, `:ilike`, `:not_like`, `:not_ilike`
- Null checks: `:is_null`, `:is_not_null`
- List operations: `:in`, `:not_in`

### Numeric Fields
Numeric fields (integer, float, decimal) support:
- Comparison: `:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte`
- Range operations: `:between`, `:not_between`
- Null checks: `:is_null`, `:is_not_null`
- List operations: `:in`, `:not_in`

### Date/DateTime Fields
Date and datetime fields support:
- Comparison: `:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte`
- Range operations: `:between`, `:not_between`
- Null checks: `:is_null`, `:is_not_null`

### Boolean Fields
Boolean fields support:
- Equality: `:eq`, `:ne`
- Null checks: `:is_null`, `:is_not_null`

## Best Practices

### Field Selection
- Always select only the fields you need for better performance
- Use `:all` sparingly, especially on tables with many columns
- Consider the impact of large text fields on query performance

### Filtering
- Use appropriate indexes for frequently filtered fields
- Prefer exact matches (`:eq`) over pattern matches (`:like`) when possible
- Use `:ilike` for case-insensitive string matching

### Aggregations
- Group by fields with good cardinality for meaningful results
- Be aware of memory usage with large result sets
- Use `LIMIT` clauses with aggregated queries when appropriate

## Performance Considerations

See the [Performance Guide](pagila_performance.md) for detailed information
about optimizing queries with these fields.
