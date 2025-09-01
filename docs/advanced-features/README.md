# Advanced SQL Features Documentation

## Overview

Selecto provides comprehensive support for advanced PostgreSQL features, enabling sophisticated data manipulation, analysis, and transformation capabilities. This documentation covers the advanced SQL features available in Selecto v0.3.0 and later.

## Features

### 📊 [Array Operations](./array-operations.md)
Comprehensive PostgreSQL array support including aggregation, manipulation, and unnesting operations.

**Key Capabilities:**
- Array aggregation (`array_agg`, `string_agg`)
- Array testing and filtering (`@>`, `<@`, `&&`)
- Array manipulation (`array_append`, `array_remove`, `array_replace`)
- Array unnesting with ordinality support
- Array transformation and type conversion

**Example:**
```elixir
selecto
|> Selecto.select([
    "category.name",
    {:array_agg, "film.title", order_by: [{"release_year", :desc}], as: "films"}
  ])
|> Selecto.group_by(["category.name"])
```

### 🔍 [JSON Operations](./json-operations.md)
Full support for PostgreSQL's JSON and JSONB data types with path queries, aggregation, and manipulation.

**Key Capabilities:**
- JSON extraction and path queries
- JSONPath expressions (PostgreSQL 12+)
- JSON aggregation (`json_agg`, `json_object_agg`)
- JSON construction and manipulation
- JSONB indexing and optimization

**Example:**
```elixir
selecto
|> Selecto.select([
    "product.name",
    {:json_get_text, "metadata", "category", as: "category"},
    {:jsonb_path_query, "specs", "$.features[*].name", as: "features"}
  ])
|> Selecto.filter([{:jsonb_contains, "metadata", %{"active" => true}}])
```

### 🔄 [Common Table Expressions (CTEs)](./cte.md)
Support for both recursive and non-recursive CTEs, enabling modular query construction and hierarchical data traversal.

**Key Capabilities:**
- Non-recursive CTEs for query organization
- Recursive CTEs for hierarchical data
- Multiple dependent CTEs
- Materialization control (PostgreSQL 12+)
- Cycle detection and depth limiting

**Example:**
```elixir
selecto
|> Selecto.with_recursive_cte("org_hierarchy",
    base_query: fn ->
      Selecto.filter([{"manager_id", nil}])
    end,
    recursive_query: fn cte ->
      Selecto.join(:inner, cte, on: "employee.manager_id = #{cte}.employee_id")
    end
  )
```

### ↔️ [LATERAL Joins](./lateral-joins.md)
Advanced join capability where the right side can reference columns from the left side, enabling correlated subqueries in joins.

**Key Capabilities:**
- Correlated subqueries in FROM clause
- Top-N queries per group
- Row-wise calculations
- Dynamic aggregations
- Integration with table functions

**Example:**
```elixir
selecto
|> Selecto.lateral_join(:left,
    fn base ->
      Selecto.select(["order_id", "total"])
      |> Selecto.filter([{"customer_id", {:ref, "customer.id"}}])
      |> Selecto.order_by([{"order_date", :desc}])
      |> Selecto.limit(5)
    end,
    as: "recent_orders"
  )
```

### 🎯 [CASE Expressions](./case-expressions.md)
Conditional logic within queries for data transformation and business rules implementation.

**Key Capabilities:**
- Simple CASE for value mapping
- Searched CASE for complex conditions
- Nested CASE expressions
- CASE in all SQL clauses
- Conditional aggregations

**Example:**
```elixir
selecto
|> Selecto.select([
    "customer.name",
    {:case_when, [
        {[{"total_spent", {:>=, 10000}}], "Platinum"},
        {[{"total_spent", {:>=, 5000}}], "Gold"},
        {[{"total_spent", {:>=, 1000}}], "Silver"}
      ],
      else: "Bronze",
      as: "tier"
    }
  ])
```

## Quick Start

### Installation

These features are included in Selecto v0.3.0+. Ensure your `mix.exs` includes:

```elixir
def deps do
  [
    {:selecto, "~> 0.3.0"}
  ]
end
```

### Basic Usage

```elixir
# Configure Selecto with your domain and connection
selecto = Selecto.configure(domain, connection)

# Use advanced features
selecto
|> Selecto.with_cte("filtered_data", fn -> ... end)
|> Selecto.select([
    {:json_get, "data", "field", as: "extracted"},
    {:array_agg, "tags", as: "all_tags"},
    {:case_when, [...], as: "category"}
  ])
|> Selecto.lateral_join(:left, fn base -> ... end, as: "related")
|> Selecto.execute()
```

## Feature Comparison

| Feature | Selecto | Raw SQL | Benefits |
|---------|---------|---------|----------|
| Array Operations | ✅ Full API | Manual | Type-safe, composable |
| JSON Operations | ✅ Full API | Manual | Automatic escaping, validation |
| CTEs | ✅ Structured | String concat | Dependency management, recursion helpers |
| LATERAL Joins | ✅ Correlated | Complex | Reference tracking, subquery builders |
| CASE Expressions | ✅ DSL | Verbose | Readable, validated conditions |

## Performance Guidelines

### Indexing Strategies

```sql
-- Array operations
CREATE INDEX idx_tags ON products USING GIN (tags);

-- JSON operations
CREATE INDEX idx_metadata ON products USING GIN (metadata jsonb_path_ops);

-- LATERAL join correlations
CREATE INDEX idx_customer_date ON orders(customer_id, order_date DESC);
```

### Query Optimization

1. **CTEs**: Use materialization hints in PostgreSQL 12+
2. **LATERAL**: Always limit result sets in subqueries
3. **JSON**: Prefer JSONB over JSON for operations
4. **Arrays**: Keep arrays under 1000 elements
5. **CASE**: Order conditions from most to least specific

## PostgreSQL Version Requirements

| Feature | Minimum Version | Recommended |
|---------|----------------|-------------|
| Basic Arrays | 9.1+ | 9.4+ |
| JSON/JSONB | 9.2+/9.4+ | 13+ |
| CTEs | 8.4+ | 12+ |
| LATERAL | 9.3+ | 9.3+ |
| CASE | All | All |
| JSONPath | 12+ | 14+ |

## Common Patterns

### Analytics Dashboard

```elixir
# Combine multiple advanced features for analytics
selecto
|> Selecto.with_cte("date_series", generate_date_series())
|> Selecto.with_cte("metrics", calculate_metrics())
|> Selecto.select([
    "date",
    {:json_build_object, [
      "revenue", "total_revenue",
      "orders", "order_count",
      "avg_order", "avg_order_value"
    ], as: "daily_metrics"},
    {:array_agg, "top_products", as: "bestsellers"}
  ])
|> Selecto.lateral_join(:left, get_top_products(), as: "top_products")
|> Selecto.group_by(["date"])
```

### Hierarchical Data with Aggregation

```elixir
# Category tree with product counts
selecto
|> Selecto.with_recursive_cte("category_tree", 
    build_category_hierarchy())
|> Selecto.select([
    "path",
    {:case_when, [
        {[{"level", 0}], "Root"},
        {[{"level", 1}], "Main Category"},
        {[true], "Subcategory"}
      ], as: "category_type"},
    {:json_agg, "product_info", as: "products"}
  ])
|> Selecto.lateral_join(:left, 
    get_category_products(), 
    as: "product_info")
|> Selecto.group_by(["category_id", "path", "level"])
```

### Dynamic Filtering and Transformation

```elixir
# Complex filtering with multiple conditions
selecto
|> Selecto.filter([
    {:jsonb_path_exists, "attributes", "$.features[*] ? (@.enabled == true)"},
    {:array_overlap, "tags", user_interests},
    {:case_when, [
        {[{"user_role", "admin"}], true},
        {[{"visibility", "public"}], true},
        {[{"owner_id", current_user}], true}
      ], else: false}
  ])
```

## Migration Guide

### From Raw SQL

```elixir
# Before: Raw SQL string
sql = """
WITH active_users AS (
  SELECT * FROM users WHERE active = true
)
SELECT 
  u.name,
  ARRAY_AGG(r.role) AS roles,
  u.metadata->>'department' AS dept
FROM active_users u
LATERAL (
  SELECT role FROM user_roles 
  WHERE user_id = u.id 
  LIMIT 5
) r
GROUP BY u.id, u.name, u.metadata
"""

# After: Selecto
selecto
|> Selecto.with_cte("active_users", fn ->
    Selecto.filter([{"active", true}])
  end)
|> Selecto.select([
    "u.name",
    {:array_agg, "r.role", as: "roles"},
    {:json_get_text, "u.metadata", "department", as: "dept"}
  ])
|> Selecto.from("active_users AS u")
|> Selecto.lateral_join(:cross, fn base ->
    Selecto.select(["role"])
    |> Selecto.from("user_roles")
    |> Selecto.filter([{"user_id", {:ref, "u.id"}}])
    |> Selecto.limit(5)
  end, as: "r")
|> Selecto.group_by(["u.id", "u.name", "u.metadata"])
```

## Best Practices

1. **Compose Incrementally**: Build complex queries step by step
2. **Use Type-Safe APIs**: Leverage Selecto's validation
3. **Test with EXPLAIN**: Verify query plans for performance
4. **Index Appropriately**: Create indexes for common patterns
5. **Limit Result Sets**: Especially in LATERAL joins and CTEs
6. **Handle NULLs**: Explicitly handle NULL values in CASE expressions
7. **Document Complex Logic**: Add comments for business rules

## Troubleshooting

### Common Issues

**CTE Not Found**
```elixir
# Ensure CTE is defined before use
|> Selecto.with_cte("my_cte", fn -> ... end)
|> Selecto.from("my_cte")  # Must come after with_cte
```

**LATERAL Reference Error**
```elixir
# Use {:ref, "column"} for outer references
|> Selecto.lateral_join(:left, fn base ->
    Selecto.filter([{"id", {:ref, "outer.id"}}])  # Correct
    # Not: {"id", "outer.id"}  # Wrong
  end)
```

**JSON Type Mismatch**
```elixir
# Check JSON value types before operations
|> Selecto.filter([
    {:and, [
      {:=, {:json_typeof, "data"}, "object"},
      {:json_has_key, "data", "field"}
    ]}
  ])
```

## Resources

### Documentation
- [Array Operations Guide](./array-operations.md)
- [JSON Operations Guide](./json-operations.md)
- [Common Table Expressions Guide](./cte.md)
- [LATERAL Joins Guide](./lateral-joins.md)
- [CASE Expressions Guide](./case-expressions.md)
- [Window Functions Guide](./window-functions.md)
- [Set Operations Guide](./set-operations.md)
- [Subqueries and Subfilters Guide](./subqueries-subfilters.md)
- [Subselects Guide](./subselects.md)
- [Parameterized Joins Guide](./parameterized-joins.md)

### PostgreSQL References
- [PostgreSQL Arrays](https://www.postgresql.org/docs/current/arrays.html)
- [PostgreSQL JSON](https://www.postgresql.org/docs/current/datatype-json.html)
- [PostgreSQL WITH Queries](https://www.postgresql.org/docs/current/queries-with.html)
- [PostgreSQL LATERAL](https://www.postgresql.org/docs/current/queries-table-expressions.html#QUERIES-LATERAL)
- [PostgreSQL CASE](https://www.postgresql.org/docs/current/functions-conditional.html)

### Examples
- [Complex Analytics Queries](../../examples/advanced-analytics.ex)
- [Hierarchical Data Patterns](../../examples/hierarchical-data.ex)
- [JSON Document Queries](../../examples/json-documents.ex)

## Contributing

We welcome contributions to improve these advanced features! Please see our [Contributing Guide](../../CONTRIBUTING.md) for details.

## Support

For questions or issues:
- GitHub Issues: [selecto/issues](https://github.com/your-org/selecto/issues)
- Documentation: [docs.selecto.dev](https://docs.selecto.dev)
- Community: [Elixir Forum](https://elixirforum.com)

## License

Selecto is released under the MIT License. See [LICENSE](../../LICENSE) for details.