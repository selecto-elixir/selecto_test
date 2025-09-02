# Subselects in Selecto

## Overview

Subselects in Selecto enable fetching related data as aggregated arrays, preventing result set denormalization while maintaining relational context. This feature is particularly useful for one-to-many relationships where you want to return related records as nested data structures rather than duplicating parent rows.

**Important:** The `subselect` function takes an array of configuration maps. The string notation shown in some examples (like `"order[product_name]") is conceptual - the actual API requires map-based configuration.

## Core Concepts

### What are Subselects?

Subselects aggregate related data into arrays or JSON structures within the main query result. Instead of joining tables and getting duplicate parent rows for each child record, subselects return all related records as a single aggregated field.

### Use Cases

- **Order Items**: Fetch all items for an order as a JSON array
- **Comments**: Get all comments for a post as an aggregated list
- **Tags**: Retrieve all tags for an article as an array
- **Related Records**: Any one-to-many relationship where you want nested data

## Basic Usage

### Simple Field Specification

```elixir
# Get attendees with their orders as JSON arrays - CORRECT API
selecto
|> Selecto.select(["attendee.name", "attendee.email"])
|> Selecto.subselect([
  %{
    fields: ["product_name", "quantity"],
    target_schema: :orders,
    format: :json_agg,
    alias: "orders",
    filter: [{"attendee_id", {:ref, "attendee.attendee_id"}}]
  }
])

# This generates SQL like:
# SELECT 
#   a.name,
#   a.email,
#   (SELECT json_agg(json_build_object(
#     'product_name', o.product_name,
#     'quantity', o.quantity
#   )) FROM orders o WHERE o.attendee_id = a.attendee_id) as orders
# FROM attendees a
```

### Multiple Fields in One Specification

```elixir
# Specify multiple fields from the same table - CORRECT API
selecto
|> Selecto.subselect([
  %{
    fields: ["product_name", "quantity", "price"],
    target_schema: :orders,
    format: :json_agg,
    alias: "order_items"
  }
])
```

### Multiple Subselects

```elixir
# Fetch multiple related datasets - CORRECT API
selecto
|> Selecto.select(["event.name", "event.date"])
|> Selecto.subselect([
  %{
    fields: ["name", "email"],
    target_schema: :attendees,
    format: :json_agg,
    alias: "attendees",
    filter: [{"event_id", {:ref, "event.id"}}]
  },
  %{
    fields: ["company", "amount"],
    target_schema: :sponsors,
    format: :json_agg,
    alias: "sponsors",
    filter: [{"event_id", {:ref, "event.id"}}]
  }
])
```

## Advanced Configuration

### Map-Based Configuration

For more control over the subselect behavior, use map-based configuration:

```elixir
selecto
|> Selecto.subselect([
  %{
    fields: ["product_name", "quantity", "price"],
    target_schema: :order,
    format: :json_agg,
    alias: "order_items",
    order_by: [{"created_at", :desc}]
  }
])
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `fields` | List of fields to include | Required |
| `target_schema` | Target table/schema atom | Auto-detected |
| `format` | Aggregation format | `:json_agg` |
| `alias` | Custom field alias | Auto-generated |
| `order_by` | Sort order for aggregated results | None |
| `filter` | Additional WHERE conditions | None |
| `limit` | Maximum records to aggregate | None |

## Aggregation Formats

### JSON Aggregation (Default)

```elixir
# Returns JSON array of objects - CORRECT API
selecto
|> Selecto.subselect([
  %{
    fields: ["product_name", "quantity"],
    target_schema: :orders,
    format: :json_agg,
    alias: "order_items"
  }
])
# Result: [{"product_name": "Widget", "quantity": 2}, ...]
```

### PostgreSQL Array Aggregation

```elixir
# Returns PostgreSQL array
selecto
|> Selecto.subselect([
  %{
    fields: ["product_name"],
    target_schema: :order,
    format: :array_agg
  }
])
# Result: {"Widget", "Gadget", "Tool"}
```

### String Aggregation

```elixir
# Returns concatenated string
selecto
|> Selecto.subselect([
  %{
    fields: ["tag_name"],
    target_schema: :tags,
    format: :string_agg,
    delimiter: ", "
  }
])
# Result: "elixir, phoenix, ecto"
```

### Count Aggregation

```elixir
# Returns count of related records
selecto
|> Selecto.subselect([
  %{
    target_schema: :comments,
    format: :count,
    alias: "comment_count"
  }
])
# Result: 42
```

## Complex Examples

### E-commerce Order Summary

```elixir
# Get customers with their order summaries
selecto
|> Selecto.select(["customer[name]", "customer[email]"])
|> Selecto.subselect([
  %{
    fields: ["order_id", "total", "status", "created_at"],
    target_schema: :orders,
    format: :json_agg,
    alias: "recent_orders",
    order_by: [{"created_at", :desc}],
    limit: 5,
    filter: [{"status", {:in, ["completed", "processing"]}}]
  }
])
|> Selecto.filter([{"customer[active]", true}])
```

### Blog Post with Related Data

```elixir
# Get blog posts with comments and tags
selecto
|> Selecto.select(["post[title]", "post[published_at]"])
|> Selecto.subselect([
  # Comments with author info
  %{
    fields: ["author_name", "content", "created_at"],
    target_schema: :comments,
    format: :json_agg,
    alias: "comments",
    order_by: [{"created_at", :desc}],
    filter: [{"approved", true}]
  },
  # Tags as simple array
  %{
    fields: ["name"],
    target_schema: :tags,
    format: :array_agg,
    alias: "tag_list"
  },
  # Comment count
  %{
    target_schema: :comments,
    format: :count,
    alias: "comment_count"
  }
])
```

### Hierarchical Data

```elixir
# Get categories with subcategories and products
selecto
|> Selecto.select(["category[name]", "category[description]"])
|> Selecto.subselect([
  # Subcategories
  %{
    fields: ["name", "product_count"],
    target_schema: :subcategories,
    format: :json_agg,
    alias: "subcategories",
    order_by: [{"name", :asc}]
  },
  # Top products
  %{
    fields: ["name", "price", "rating"],
    target_schema: :products,
    format: :json_agg,
    alias: "top_products",
    order_by: [{"rating", :desc}, {"sales_count", :desc}],
    limit: 10
  }
])
|> Selecto.filter([{"category[active]", true}])
```

## Performance Considerations

### Indexing

Ensure proper indexes on foreign key columns used in subselect correlations:

```sql
-- Index for subselect correlation
CREATE INDEX idx_orders_attendee_id ON orders(attendee_id);

-- Composite index for filtered subselects
CREATE INDEX idx_comments_post_approved 
  ON comments(post_id, approved) 
  WHERE approved = true;

-- Index for ordered subselects
CREATE INDEX idx_orders_customer_created 
  ON orders(customer_id, created_at DESC);
```

### Query Optimization

1. **Use LIMIT in subselects** when you only need recent/top records
2. **Add filters** to reduce the amount of data aggregated
3. **Consider materialized views** for frequently accessed aggregations
4. **Use appropriate formats** - JSON is flexible but arrays are faster
5. **Monitor query plans** with EXPLAIN ANALYZE

### N+1 Query Prevention

Subselects execute as correlated subqueries, which effectively prevents N+1 problems:

```elixir
# This executes as a single query, not N+1
selecto
|> Selecto.select(["author[name]"])
|> Selecto.subselect(["posts[title, view_count]"])
|> Selecto.limit(100)

# Generated SQL uses correlated subquery:
# SELECT 
#   a.name,
#   (SELECT json_agg(...) FROM posts p WHERE p.author_id = a.id) as posts
# FROM authors a
# LIMIT 100
```

## Integration with Other Features

### With Filters

```elixir
# Subselects work with main query filters
selecto
|> Selecto.select(["event[name]"])
|> Selecto.subselect(["attendees[name, email]"])
|> Selecto.filter([
  {"event[date]", {:>=, ~D[2024-01-01]}},
  {"event[status]", "active"}
])
```

### With Joins

```elixir
# Combine joins and subselects
selecto
|> Selecto.join(:inner, :venue)
|> Selecto.select(["event[name]", "venue[name]"])
|> Selecto.subselect(["attendees[name]"])
```

### With Aggregations

```elixir
# Main query aggregation with subselects
selecto
|> Selecto.select([
  "category[name]",
  {:count, "product[id]", as: "product_count"}
])
|> Selecto.subselect([
  %{
    fields: ["name", "price"],
    target_schema: :products,
    format: :json_agg,
    alias: "sample_products",
    limit: 3
  }
])
|> Selecto.group_by(["category[id]", "category[name]"])
```

## Common Patterns

### Latest Records Pattern

```elixir
# Get latest N related records
%{
  fields: ["id", "message", "created_at"],
  target_schema: :notifications,
  format: :json_agg,
  order_by: [{"created_at", :desc}],
  limit: 5,
  alias: "recent_notifications"
}
```

### Conditional Aggregation Pattern

```elixir
# Different aggregations based on conditions
selecto
|> Selecto.subselect([
  %{
    target_schema: :orders,
    format: :count,
    filter: [{"status", "pending"}],
    alias: "pending_count"
  },
  %{
    target_schema: :orders,
    format: :count,
    filter: [{"status", "completed"}],
    alias: "completed_count"
  }
])
```

### Nested JSON Pattern

```elixir
# Build complex nested structures
%{
  fields: [
    "id",
    "name",
    {:json_build_object, [
      "created", "created_at",
      "updated", "updated_at"
    ], as: "timestamps"}
  ],
  target_schema: :items,
  format: :json_agg
}
```

## Error Handling

### Common Errors

1. **Invalid target schema**
```elixir
# Error: Schema not found in domain
selecto |> Selecto.subselect(["nonexistent[field]"])
```

2. **Invalid field specification**
```elixir
# Error: Field not found in schema
selecto |> Selecto.subselect(["order[invalid_field]"])
```

3. **Missing relationship**
```elixir
# Error: No relationship path found
# Ensure proper associations are defined in domain
```

## Best Practices

1. **Use specific field lists** instead of selecting all fields
2. **Apply filters** to subselects to reduce data volume
3. **Order and limit** results when only recent/top records are needed
4. **Choose appropriate formats** - JSON for flexibility, arrays for performance
5. **Consider caching** for expensive subselect queries
6. **Monitor performance** with query analysis tools
7. **Index foreign keys** used in subselect correlations

## Comparison with Joins

| Aspect | Subselects | Joins |
|--------|------------|-------|
| Result Structure | Nested arrays/JSON | Flat, denormalized |
| Row Count | One row per parent | Multiple rows per parent |
| Performance | Single query, correlated | Can be faster for small datasets |
| Use Case | One-to-many with nesting | Many-to-many or filtering |
| Data Transfer | Less duplication | More data transferred |

## Limitations

1. **Correlation requirement**: Subselects require a correlation path between tables
2. **Aggregation overhead**: Large aggregations can impact performance
3. **Format constraints**: Some formats have type restrictions
4. **Database support**: Requires PostgreSQL 9.4+ for JSON aggregation

## See Also

- [JSON Operations](./json-operations.md) - Working with JSON data
- [Array Operations](./array-operations.md) - Array manipulation functions
- [Subqueries and Subfilters](./subqueries-subfilters.md) - Query composition
- [Performance Tuning Guide](../guides/performance.md) - Optimization strategies