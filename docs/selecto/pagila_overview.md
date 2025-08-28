# Pagila Domain Overview

This document provides a comprehensive overview of the pagila domain configuration
for Selecto query building and data visualization.

## Domain Structure

The pagila domain is built around the `pagila` table as its
primary data source, with the following key characteristics:

### Primary Source
- **Table**: `pagila`
- **Primary Key**: `id`
- **Field Count**: 4

### Available Fields
- **id** (`integer`)
- **name** (`string`)
- **created_at** (`datetime`)
- **updated_at** (`datetime`)

## Usage Patterns

The pagila domain supports the following common usage patterns:

### Basic Queries
```elixir
# Select all records
Selecto.select(pagila_domain(), [:id, :name])

# Filter by specific criteria
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.filter(:name, :eq, "example")
```

### Aggregations
```elixir
# Count records
Selecto.select(pagila_domain(), [:count])
|> Selecto.aggregate(:count, :id)

# Group by fields
Selecto.select(pagila_domain(), [:name, :count])
|> Selecto.group_by([:name])
|> Selecto.aggregate(:count, :id)
```

## Related Documentation

- [Field Reference](pagila_fields.md) - Complete field reference
- [Joins Guide](pagila_joins.md) - Join relationships and optimization
- [Examples](pagila_examples.md) - Code examples and patterns
- [Performance Guide](pagila_performance.md) - Performance considerations

## Quick Start

To use this domain in your application:

1. Include the domain module in your query context
2. Configure your database connection
3. Start building queries using the Selecto API

```elixir
# Example usage in LiveView
def mount(_params, _session, socket) do
  initial_data = 
    Selecto.select(pagila_domain(), [:id, :name])
    |> Selecto.limit(10)
    |> Selecto.execute(MyApp.Repo)

  {:ok, assign(socket, data: initial_data)}
end
```

For more detailed examples and advanced usage patterns, see the 
[Examples Documentation](pagila_examples.md).
