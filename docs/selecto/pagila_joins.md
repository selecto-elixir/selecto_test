# Pagila Domain Joins Guide

This document explains how to work with joins and relationships in the pagila domain,
including performance optimization and best practices.

## Available Joins

No predefined joins are configured for this domain. You can create custom joins
using the Selecto join API:

```elixir
# Example custom join
Selecto.select(your_domain(), [:id, :name])
|> Selecto.join(:inner, :related_table, :foreign_key_id, :id)
```


## Join Syntax

### Basic Join Operations
```elixir
# Inner join with related table
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.join(:inner, :related_table, :id, :pagila_id)
```

### Advanced Join Patterns
```elixir
# Multiple joins
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.join(:inner, :categories, :category_id, :id)
|> Selecto.join(:left, :tags, :id, :pagila_id)
```

## Join Types

### Inner Joins
Inner joins return only records that have matching values in both tables.

**Use when**: You need records that definitely have related data.

```elixir
# Only pagilas that have categories
Selecto.select(pagila_domain(), [:id, :name, "categories.name as category_name"])
|> Selecto.join(:inner, :categories, :category_id, :id)
```

### Left Joins
Left joins return all records from the left table, with matching records from the right table.

**Use when**: You want all main records, even if they don't have related data.

```elixir
# All pagilas, with category names when available
Selecto.select(pagila_domain(), [:id, :name, "categories.name as category_name"])
|> Selecto.join(:left, :categories, :category_id, :id)
```

### Right Joins
Right joins return all records from the right table, with matching records from the left table.

**Use when**: You want all related records, even if they don't have main records.

### Full Outer Joins
Full outer joins return records when there's a match in either table.

**Use when**: You need comprehensive data from both tables.

## Performance Optimization

### Index Usage
Ensure proper indexes exist for join conditions:

```sql
-- Example indexes for common joins
CREATE INDEX idx_pagila_category_id ON pagila (category_id);
CREATE INDEX idx_categories_id ON categories (id);
```

### Join Order Optimization
- Start with the most selective table (smallest result set)
- Place most restrictive filters early in the query
- Use EXPLAIN ANALYZE to verify query performance

### Query Hints
```elixir
# Prefer hash joins for large result sets
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.join(:inner, :large_table, :id, :pagila_id, hint: :hash)

# Prefer nested loop joins for small result sets
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.join(:inner, :small_table, :id, :pagila_id, hint: :nested_loop)
```

## Common Join Patterns

### One-to-Many Relationships
```elixir
# Pagila with multiple related records
Selecto.select(pagila_domain(), [:id, :name, "tags.name as tag_name"])
|> Selecto.join(:left, :pagila_tags, :id, :pagila_id)
|> Selecto.join(:left, :tags, "pagila_tags.tag_id", "tags.id")
```

### Many-to-Many Relationships
```elixir
# Pagila with many-to-many through junction table
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.join(:inner, :pagila_categories, :id, :pagila_id)
|> Selecto.join(:inner, :categories, "pagila_categories.category_id", "categories.id")
|> Selecto.filter("categories.active", :eq, true)
```

### Self-Referential Joins
```elixir
# Hierarchical data (parent-child relationships)
Selecto.select(pagila_domain(), [:id, :name, "parent.name as parent_name"])
|> Selecto.join(:left, :pagila, :parent_id, :id, alias: "parent")
```

## Troubleshooting

### Common Issues

**Cartesian Products**: Occurs when join conditions are missing or incorrect.
```elixir
# Wrong - missing join condition
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.join(:inner, :categories)  # Missing ON condition

# Correct - proper join condition
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.join(:inner, :categories, :category_id, :id)
```

**Duplicate Records**: Occurs with one-to-many joins without proper grouping.
```elixir
# May produce duplicates
Selecto.select(pagila_domain(), [:id, :name, "tags.name"])
|> Selecto.join(:left, :tags, :id, :pagila_id)

# Use aggregation to avoid duplicates
Selecto.select(pagila_domain(), [:id, :name, "STRING_AGG(tags.name, ', ') as tag_names"])
|> Selecto.join(:left, :tags, :id, :pagila_id)
|> Selecto.group_by([:id, :name])
```

### Performance Issues

**Slow Joins**: Usually caused by missing indexes or poor query structure.

1. Check for appropriate indexes on join columns
2. Analyze query execution plan
3. Consider query restructuring or breaking into multiple queries

**Memory Issues**: Large result sets from joins can cause memory problems.

1. Use pagination with `LIMIT` and `OFFSET`
2. Consider using cursors for large datasets
3. Stream results when possible

## Best Practices

1. **Always use explicit join conditions** - Don't rely on implicit relationships
2. **Index foreign key columns** - Critical for join performance  
3. **Use appropriate join types** - Don't use INNER when you need LEFT
4. **Test with realistic data volumes** - Performance characteristics change with scale
5. **Monitor query performance** - Use database profiling tools regularly
6. **Consider denormalization** - Sometimes avoiding joins improves performance

## Related Documentation

- [Performance Guide](pagila_performance.md) - Detailed performance optimization
- [Examples](pagila_examples.md) - Real-world join examples
- [Field Reference](pagila_fields.md) - Available fields for joins
