# Array Operations Guide

## Overview

Selecto provides comprehensive support for PostgreSQL array operations, enabling powerful list manipulation, aggregation, and transformation capabilities. This guide covers all array functions available in Selecto and demonstrates common usage patterns.

**Note:** Array operations are integrated into Selecto's standard `select` and `filter` functions. There are no separate `array_select` or `array_filter` functions - instead, use array operations within the existing API.

## Table of Contents

1. [Array Aggregation](#array-aggregation)
2. [Array Testing and Filtering](#array-testing-and-filtering)
3. [Array Size Operations](#array-size-operations)
4. [Array Construction](#array-construction)
5. [Array Manipulation](#array-manipulation)
6. [Array Transformation](#array-transformation)
7. [Array Unnesting](#array-unnesting)
8. [Advanced Patterns](#advanced-patterns)

## Array Aggregation

### array_agg - Aggregate Values into Array

Collects values into an array during aggregation.

```elixir
# Basic array aggregation
selecto
|> Selecto.select([
    "category.name",
    {:array_agg, "film.title", as: "film_titles"}
  ])
|> Selecto.group_by(["category.name"])

# With DISTINCT values
selecto
|> Selecto.select([
    "actor.first_name",
    {:array_agg, "film.rating", distinct: true, as: "unique_ratings"}
  ])
|> Selecto.group_by(["actor.actor_id", "actor.first_name"])

# With ORDER BY
selecto
|> Selecto.select([
    "category.name",
    {:array_agg, "film.title", 
      order_by: [{"film.release_year", :desc}, {"film.title", :asc}],
      as: "films_by_year"}
  ])
|> Selecto.group_by(["category.name"])
```

**Generated SQL:**
```sql
-- Basic
SELECT category.name, ARRAY_AGG(film.title) AS film_titles
FROM category
GROUP BY category.name;

-- With DISTINCT
SELECT actor.first_name, ARRAY_AGG(DISTINCT film.rating) AS unique_ratings
FROM actor
GROUP BY actor.actor_id, actor.first_name;

-- With ORDER BY
SELECT category.name, 
       ARRAY_AGG(film.title ORDER BY film.release_year DESC, film.title ASC) AS films_by_year
FROM category
GROUP BY category.name;
```

### string_agg - Concatenate Values into String

Aggregates values into a delimited string.

```elixir
selecto
|> Selecto.select([
    "category.name",
    {:string_agg, "film.title", delimiter: ", ", as: "film_list"},
    {:string_agg, "actor.last_name", 
      delimiter: " | ", 
      order_by: [{"actor.last_name", :asc}],
      as: "actor_names"}
  ])
|> Selecto.group_by(["category.name"])
```

**Generated SQL:**
```sql
SELECT category.name,
       STRING_AGG(film.title, ', ') AS film_list,
       STRING_AGG(actor.last_name, ' | ' ORDER BY actor.last_name ASC) AS actor_names
FROM category
GROUP BY category.name;
```

## Array Testing and Filtering

### Array Containment Operators

Test array relationships using PostgreSQL's array operators.

```elixir
# Array contains - @>
selecto
|> Selecto.filter([
    {:array_contains, "film.special_features", ["Trailers", "Deleted Scenes"]}
  ])

# Array is contained by - <@
selecto
|> Selecto.filter([
    {:array_contained, "user.permissions", ["read", "write", "admin"]}
  ])

# Array overlap - &&
selecto
|> Selecto.filter([
    {:array_overlap, "product.tags", ["electronics", "computers", "tablets"]}
  ])

# Array equality - =
selecto
|> Selecto.filter([
    {:array_eq, "film.special_features", ["Trailers", "Commentaries"]}
  ])
```

**Generated SQL:**
```sql
-- Contains
WHERE film.special_features @> ARRAY['Trailers', 'Deleted Scenes'];

-- Contained by
WHERE user.permissions <@ ARRAY['read', 'write', 'admin'];

-- Overlap
WHERE product.tags && ARRAY['electronics', 'computers', 'tablets'];

-- Equality
WHERE film.special_features = ARRAY['Trailers', 'Commentaries'];
```

## Array Size Operations

### Getting Array Dimensions and Length

```elixir
# Array length at specific dimension
selecto
|> Selecto.select([
    "product.name",
    {:array_length, "product.tags", 1, as: "tag_count"}
  ])

# Total elements (cardinality)
selecto
|> Selecto.select([
    "matrix.name",
    {:cardinality, "matrix.data", as: "total_elements"}
  ])

# Number of dimensions
selecto
|> Selecto.select([
    "dataset.name",
    {:array_ndims, "dataset.values", as: "dimensions"}
  ])

# Array dimension sizes
selecto
|> Selecto.select([
    "matrix.name",
    {:array_dims, "matrix.data", as: "dimension_info"}
  ])
```

**Generated SQL:**
```sql
-- Length
SELECT product.name, ARRAY_LENGTH(product.tags, 1) AS tag_count;

-- Cardinality
SELECT matrix.name, CARDINALITY(matrix.data) AS total_elements;

-- Number of dimensions
SELECT dataset.name, ARRAY_NDIMS(dataset.values) AS dimensions;

-- Dimension info
SELECT matrix.name, ARRAY_DIMS(matrix.data) AS dimension_info;
```

## Array Construction

### Building Arrays Dynamically

```elixir
# Construct array from values
selecto
|> Selecto.select([
    "order.id",
    {:array, ["pending", "processing", "shipped"], as: "status_flow"}
  ])

# Append element to array
selecto
|> Selecto.select([
    "product.name",
    {:array_append, "product.tags", "new-arrival", as: "updated_tags"}
  ])

# Prepend element to array
selecto
|> Selecto.select([
    "notification.id",
    {:array_prepend, "urgent", "notification.types", as: "prioritized_types"}
  ])

# Concatenate arrays
selecto
|> Selecto.select([
    "user.name",
    {:array_cat, "user.roles", ["viewer", "commenter"], as: "all_roles"}
  ])

# Fill array with value
selecto
|> Selecto.select([
    "grid.name",
    {:array_fill, 0, dimensions: [10, 10], as: "empty_grid"}
  ])
```

**Generated SQL:**
```sql
-- Array construction
SELECT order.id, ARRAY['pending', 'processing', 'shipped'] AS status_flow;

-- Append
SELECT product.name, ARRAY_APPEND(product.tags, 'new-arrival') AS updated_tags;

-- Prepend
SELECT notification.id, ARRAY_PREPEND('urgent', notification.types) AS prioritized_types;

-- Concatenate
SELECT user.name, ARRAY_CAT(user.roles, ARRAY['viewer', 'commenter']) AS all_roles;

-- Fill
SELECT grid.name, ARRAY_FILL(0, ARRAY[10, 10]) AS empty_grid;
```

## Array Manipulation

### Modifying Array Contents

```elixir
# Remove element from array
selecto
|> Selecto.select([
    "product.name",
    {:array_remove, "product.tags", "deprecated", as: "cleaned_tags"}
  ])

# Replace element in array
selecto
|> Selecto.select([
    "document.title",
    {:array_replace, "document.tags", "draft", "published", as: "updated_tags"}
  ])

# Find position of element
selecto
|> Selecto.select([
    "playlist.name",
    {:array_position, "playlist.songs", "favorite_song_id", as: "position"}
  ])

# Find all positions of element
selecto
|> Selecto.select([
    "text.content",
    {:array_positions, "text.keywords", "important", as: "important_positions"}
  ])
```

**Generated SQL:**
```sql
-- Remove
SELECT product.name, ARRAY_REMOVE(product.tags, 'deprecated') AS cleaned_tags;

-- Replace
SELECT document.title, 
       ARRAY_REPLACE(document.tags, 'draft', 'published') AS updated_tags;

-- Position
SELECT playlist.name, 
       ARRAY_POSITION(playlist.songs, 'favorite_song_id') AS position;

-- All positions
SELECT text.content, 
       ARRAY_POSITIONS(text.keywords, 'important') AS important_positions;
```

## Array Transformation

### Converting Arrays to Other Types

```elixir
# Array to string
selecto
|> Selecto.select([
    "product.name",
    {:array_to_string, "product.tags", ", ", as: "tag_list"}
  ])

# String to array
selecto
|> Selecto.select([
    "csv_data.row",
    {:string_to_array, "csv_data.values", ",", as: "parsed_values"}
  ])

# Array to string with null handling
selecto
|> Selecto.select([
    "report.name",
    {:array_to_string, "report.data", " | ", null_string: "N/A", as: "formatted_data"}
  ])
```

**Generated SQL:**
```sql
-- Array to string
SELECT product.name, ARRAY_TO_STRING(product.tags, ', ') AS tag_list;

-- String to array
SELECT csv_data.row, STRING_TO_ARRAY(csv_data.values, ',') AS parsed_values;

-- With null handling
SELECT report.name, 
       ARRAY_TO_STRING(report.data, ' | ', 'N/A') AS formatted_data;
```

## Array Unnesting

### Expanding Arrays into Rows

```elixir
# Basic unnest
selecto
|> Selecto.select(["film.title", "feature"])
|> Selecto.unnest("film.special_features", as: "feature")

# Unnest with ordinality (position)
selecto
|> Selecto.select(["product.name", "tag.value", "tag.position"])
|> Selecto.unnest("product.tags", as: "tag", with_ordinality: true)

# Multiple unnests
selecto
|> Selecto.select(["order.id", "item", "quantity"])
|> Selecto.unnest("order.items", as: "item")
|> Selecto.unnest("order.quantities", as: "quantity")
```

**Generated SQL:**
```sql
-- Basic unnest
SELECT film.title, feature
FROM film, UNNEST(film.special_features) AS feature;

-- With ordinality
SELECT product.name, tag.value, tag.ordinality AS position
FROM product, UNNEST(product.tags) WITH ORDINALITY AS tag(value, ordinality);

-- Multiple unnests
SELECT order.id, item, quantity
FROM order,
     UNNEST(order.items) AS item,
     UNNEST(order.quantities) AS quantity;
```

## Advanced Patterns

### Complex Array Queries

#### Finding Products with Specific Tag Combinations

```elixir
selecto
|> Selecto.select(["product.name", "product.price"])
|> Selecto.filter([
    # Must have all these tags
    {:array_contains, "product.tags", ["electronics", "wireless"]},
    # Must have at least one of these
    {:array_overlap, "product.tags", ["bluetooth", "wifi", "5g"]},
    # Must not have these tags
    {:not, {:array_overlap, "product.tags", ["discontinued", "recalled"]}}
  ])
```

#### Aggregating Arrays of Arrays

```elixir
# Flatten nested arrays
selecto
|> Selecto.select([
    "category.name",
    {:array_agg, {:unnest, "product.tags"}, distinct: true, as: "all_tags"}
  ])
|> Selecto.group_by(["category.name"])
```

#### Array-based Ranking

```elixir
# Rank products by number of matching tags
search_tags = ["laptop", "gaming", "portable"]

selecto
|> Selecto.select([
    "product.name",
    "product.price",
    {:cardinality, 
      {:array_intersect, "product.tags", search_tags}, 
      as: "match_count"}
  ])
|> Selecto.order_by([{"match_count", :desc}])
```

### Performance Optimization

#### Indexing Array Columns

```sql
-- GIN index for array containment queries
CREATE INDEX idx_product_tags ON products USING GIN (tags);

-- GiST index for array overlap queries
CREATE INDEX idx_special_features ON films USING GIST (special_features);
```

#### Query Optimization Tips

1. **Use specific operators**: `@>` and `<@` are more efficient than generic functions
2. **Index appropriately**: GIN indexes are best for containment, GiST for overlap
3. **Limit array sizes**: Keep arrays under 1000 elements for best performance
4. **Consider unnesting**: For complex joins, unnesting may be more efficient
5. **Use DISTINCT wisely**: `array_agg(DISTINCT ...)` can be expensive on large datasets

### Common Use Cases

#### Tag Management System

```elixir
# Add a new tag to all products in a category
selecto
|> Selecto.update([
    {:array_append, "tags", "seasonal", as: "tags"}
  ])
|> Selecto.filter([{"category_id", 5}])

# Find products with similar tags
base_product_tags = ["laptop", "gaming", "rgb", "mechanical"]

selecto
|> Selecto.select([
    "product.name",
    {:cardinality,
      {:array_intersect, "product.tags", base_product_tags},
      as: "similarity_score"}
  ])
|> Selecto.filter([
    {"product.id", {:!=, base_product_id}},
    {:array_overlap, "product.tags", base_product_tags}
  ])
|> Selecto.order_by([{"similarity_score", :desc}])
|> Selecto.limit(10)
```

#### Multi-value Attributes

```elixir
# Find films with specific feature combinations
selecto
|> Selecto.select(["film.title", "film.rating"])
|> Selecto.filter([
    {:array_contains, "special_features", ["Commentary"]},
    {:or, [
      {:array_contains, "special_features", ["Deleted Scenes"]},
      {:array_contains, "special_features", ["Behind the Scenes"]}
    ]}
  ])
```

#### Permission Systems

```elixir
# Check if user has required permissions
required_permissions = ["read", "write", "delete"]

selecto
|> Selecto.select(["user.email", "user.name"])
|> Selecto.filter([
    {:array_contains, "user.permissions", required_permissions}
  ])

# Find users with any admin permission
selecto
|> Selecto.select(["user.email", {:array_to_string, "permissions", ", ", as: "permission_list"}])
|> Selecto.filter([
    {:array_overlap, "user.permissions", ["admin", "superadmin", "moderator"]}
  ])
```

## API Reference

### Array Aggregation Functions

- `array_agg(column, opts)` - Aggregate values into array
  - Options: `distinct: boolean`, `order_by: list`, `as: string`
- `string_agg(column, opts)` - Aggregate values into delimited string
  - Options: `delimiter: string`, `order_by: list`, `as: string`

### Array Testing Functions

- `array_contains(column, value)` - Test if array contains all elements
- `array_contained(column, value)` - Test if array is contained by value
- `array_overlap(column, value)` - Test if arrays have common elements
- `array_eq(column, value)` - Test if arrays are equal

### Array Size Functions

- `array_length(column, dimension, opts)` - Get array length at dimension
- `cardinality(column, opts)` - Get total number of elements
- `array_ndims(column, opts)` - Get number of dimensions
- `array_dims(column, opts)` - Get dimension information

### Array Construction Functions

- `array(values, opts)` - Construct array from values
- `array_append(column, value, opts)` - Append element to array
- `array_prepend(value, column, opts)` - Prepend element to array
- `array_cat(column1, column2, opts)` - Concatenate arrays
- `array_fill(value, opts)` - Create array filled with value

### Array Manipulation Functions

- `array_remove(column, value, opts)` - Remove all occurrences of element
- `array_replace(column, from, to, opts)` - Replace elements in array
- `array_position(column, value, opts)` - Find first position of element
- `array_positions(column, value, opts)` - Find all positions of element

### Array Transformation Functions

- `array_to_string(column, delimiter, opts)` - Convert array to string
- `string_to_array(column, delimiter, opts)` - Convert string to array
- `unnest(column, opts)` - Expand array into rows
  - Options: `as: string`, `with_ordinality: boolean`

## Error Handling

Common errors and their solutions:

```elixir
# ERROR: operator does not exist: text[] @> text
# Solution: Ensure both operands are arrays
{:array_contains, "tags", ["value"]}  # Correct
{:array_contains, "tags", "value"}    # Incorrect - right side must be array

# ERROR: function array_length(text[]) does not exist
# Solution: Provide dimension parameter
{:array_length, "tags", 1, as: "count"}  # Correct
{:array_length, "tags", as: "count"}     # Incorrect - missing dimension

# ERROR: cannot accumulate arrays of different dimensionality
# Solution: Ensure consistent array dimensions in aggregation
{:array_agg, "flat_array", as: "collection"}     # 1D arrays
{:array_agg, "matrix_column", as: "matrices"}   # 2D arrays - keep separate
```

## PostgreSQL Version Compatibility

| Feature | Min Version | Notes |
|---------|-------------|-------|
| Basic array operations | 9.1+ | Core array support |
| `array_agg` | 9.0+ | Basic aggregation |
| `array_agg` with ORDER BY | 9.0+ | Ordered aggregation |
| `cardinality` | 9.4+ | Preferred over array_length |
| Array operators (@>, <@, &&) | 8.2+ | GIN index support |
| `array_position/positions` | 9.5+ | Element searching |
| `array_remove/replace` | 9.3+ | Array manipulation |
| UNNEST WITH ORDINALITY | 9.4+ | Position tracking |

## Best Practices

1. **Choose the right index**: Use GIN for containment queries, GiST for proximity
2. **Normalize when appropriate**: Consider separate tables for frequently queried arrays
3. **Limit array sizes**: Arrays over 1000 elements impact performance
4. **Use appropriate operators**: Native operators (@>, <@) are faster than functions
5. **Consider data types**: Use consistent types within arrays
6. **Handle NULLs explicitly**: Arrays can contain NULLs which affect comparisons
7. **Test with production data**: Array performance varies with size and content

## See Also

- [PostgreSQL Arrays Documentation](https://www.postgresql.org/docs/current/arrays.html)
- [JSON Operations Guide](./json-operations.md)
- [Window Functions Guide](./window-functions.md)
- [Common Table Expressions Guide](./cte.md)