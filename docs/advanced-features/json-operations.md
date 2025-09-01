# JSON Operations Guide

## Overview

Selecto provides comprehensive support for PostgreSQL's JSON and JSONB data types, enabling powerful document querying, manipulation, and aggregation. This guide covers all JSON operations available in Selecto with practical examples and best practices.

## Table of Contents

1. [JSON vs JSONB](#json-vs-jsonb)
2. [JSON Extraction](#json-extraction)
3. [JSON Path Queries](#json-path-queries)
4. [JSON Testing and Filtering](#json-testing-and-filtering)
5. [JSON Aggregation](#json-aggregation)
6. [JSON Construction](#json-construction)
7. [JSON Manipulation](#json-manipulation)
8. [Advanced Patterns](#advanced-patterns)
9. [Performance Optimization](#performance-optimization)

## JSON vs JSONB

PostgreSQL offers two JSON data types:

- **JSON**: Stores exact text representation, preserves formatting and key order
- **JSONB**: Binary format, faster operations, supports indexing, removes duplicates

```elixir
# Selecto works with both types
selecto
|> Selecto.select([
    {:json_extract, "config", "$.theme", as: "theme"},      # JSON column
    {:jsonb_extract, "metadata", "$.tags", as: "tags"}      # JSONB column
  ])
```

## JSON Extraction

### Basic Extraction Operators

```elixir
# Extract JSON object field (returns JSON)
selecto
|> Selecto.select([
    "product.name",
    {:json_get, "product.data", "specifications", as: "specs"}  # -> operator
  ])

# Extract JSON value as text
selecto
|> Selecto.select([
    "product.name", 
    {:json_get_text, "product.data", "brand", as: "brand"}  # ->> operator
  ])

# Extract nested values
selecto
|> Selecto.select([
    "product.name",
    {:json_get_path, "product.data", ["specs", "dimensions", "weight"], as: "weight"}
  ])

# Multiple extraction in one query
selecto
|> Selecto.select([
    "order.id",
    {:json_get_text, "order.data", "customer_name", as: "customer"},
    {:json_get_text, "order.data", "total", as: "order_total"},
    {:json_get, "order.data", "items", as: "order_items"}
  ])
```

**Generated SQL:**
```sql
-- Object field extraction
SELECT product.name, product.data->'specifications' AS specs;

-- Text extraction  
SELECT product.name, product.data->>'brand' AS brand;

-- Nested extraction
SELECT product.name, product.data#>'{specs,dimensions,weight}' AS weight;

-- Multiple extractions
SELECT order.id,
       order.data->>'customer_name' AS customer,
       order.data->>'total' AS order_total,
       order.data->'items' AS order_items;
```

### Array Element Access

```elixir
# Access array element by index
selecto
|> Selecto.select([
    "product.name",
    {:json_get_array_element, "product.tags", 0, as: "primary_tag"},
    {:json_get_array_element_text, "product.tags", 1, as: "secondary_tag"}
  ])

# Access nested array elements
selecto
|> Selecto.select([
    "order.id",
    {:json_get_path, "order.data", ["items", "0", "product_id"], as: "first_product"}
  ])
```

**Generated SQL:**
```sql
-- Array element access
SELECT product.name,
       product.tags->0 AS primary_tag,
       product.tags->>1 AS secondary_tag;

-- Nested array access
SELECT order.id,
       order.data#>'{items,0,product_id}' AS first_product;
```

## JSON Path Queries

### JSONPath Expressions

PostgreSQL 12+ supports SQL/JSON path expressions for complex queries.

```elixir
# JSONPath queries
selecto
|> Selecto.select([
    "product.name",
    {:jsonb_path_query, "product.data", "$.features[*].name", as: "feature_names"},
    {:jsonb_path_query_first, "product.data", "$.price", as: "price"}
  ])

# JSONPath with filters
selecto
|> Selecto.select([
    "order.id",
    {:jsonb_path_query, "order.items", 
      "$[*] ? (@.quantity > 2)", 
      as: "bulk_items"}
  ])

# JSONPath exists check
selecto
|> Selecto.filter([
    {:jsonb_path_exists, "product.data", "$.specifications.warranty"}
  ])
```

**Generated SQL:**
```sql
-- JSONPath queries
SELECT product.name,
       jsonb_path_query(product.data, '$.features[*].name') AS feature_names,
       jsonb_path_query_first(product.data, '$.price') AS price;

-- With filters
SELECT order.id,
       jsonb_path_query(order.items, '$[*] ? (@.quantity > 2)') AS bulk_items;

-- Exists check
WHERE jsonb_path_exists(product.data, '$.specifications.warranty');
```

## JSON Testing and Filtering

### Containment and Existence

```elixir
# JSON contains - @>
selecto
|> Selecto.filter([
    {:jsonb_contains, "product.metadata", %{"category" => "electronics"}}
  ])

# JSON is contained by - <@
selecto
|> Selecto.filter([
    {:jsonb_contained, "user.preferences", %{"theme" => "dark", "language" => "en"}}
  ])

# Key exists - ?
selecto
|> Selecto.filter([
    {:jsonb_has_key, "product.data", "specifications"}
  ])

# Any keys exist - ?|
selecto
|> Selecto.filter([
    {:jsonb_has_any_key, "product.tags", ["new", "featured", "sale"]}
  ])

# All keys exist - ?&
selecto
|> Selecto.filter([
    {:jsonb_has_all_keys, "product.required_fields", ["name", "price", "sku"]}
  ])
```

**Generated SQL:**
```sql
-- Contains
WHERE product.metadata @> '{"category": "electronics"}';

-- Contained by
WHERE user.preferences <@ '{"theme": "dark", "language": "en"}';

-- Key exists
WHERE product.data ? 'specifications';

-- Any keys exist
WHERE product.tags ?| ARRAY['new', 'featured', 'sale'];

-- All keys exist  
WHERE product.required_fields ?& ARRAY['name', 'price', 'sku'];
```

### JSON Type Checking

```elixir
# Check JSON value type
selecto
|> Selecto.select([
    "config.name",
    {:json_typeof, "config.value", as: "value_type"}
  ])
|> Selecto.filter([
    {:json_typeof, "config.value", "object"}
  ])

# Check array length
selecto
|> Selecto.select([
    "product.name",
    {:json_array_length, "product.images", as: "image_count"}
  ])
|> Selecto.filter([
    {:>, {:json_array_length, "product.images"}, 3}
  ])
```

**Generated SQL:**
```sql
-- Type checking
SELECT config.name, json_typeof(config.value) AS value_type
WHERE json_typeof(config.value) = 'object';

-- Array length
SELECT product.name, json_array_length(product.images) AS image_count
WHERE json_array_length(product.images) > 3;
```

## JSON Aggregation

### Aggregating Data into JSON

```elixir
# Aggregate rows into JSON array
selecto
|> Selecto.select([
    "category.name",
    {:json_agg, "product.name", as: "product_names"},
    {:jsonb_agg, {:json_build_object, [
      "id", "product.id",
      "name", "product.name", 
      "price", "product.price"
    ]}, as: "products"}
  ])
|> Selecto.group_by(["category.name"])

# Create JSON object from key-value pairs
selecto
|> Selecto.select([
    "order.id",
    {:json_object_agg, "item.sku", "item.quantity", as: "items_map"}
  ])
|> Selecto.group_by(["order.id"])

# Aggregate with ordering
selecto
|> Selecto.select([
    "author.name",
    {:json_agg, "post.title", 
      order_by: [{"post.created_at", :desc}],
      as: "recent_posts"}
  ])
|> Selecto.group_by(["author.name"])
```

**Generated SQL:**
```sql
-- JSON array aggregation
SELECT category.name,
       JSON_AGG(product.name) AS product_names,
       JSONB_AGG(
         JSON_BUILD_OBJECT(
           'id', product.id,
           'name', product.name,
           'price', product.price
         )
       ) AS products
FROM category
GROUP BY category.name;

-- Object aggregation
SELECT order.id,
       JSON_OBJECT_AGG(item.sku, item.quantity) AS items_map
FROM order
GROUP BY order.id;

-- Ordered aggregation
SELECT author.name,
       JSON_AGG(post.title ORDER BY post.created_at DESC) AS recent_posts
FROM author
GROUP BY author.name;
```

## JSON Construction

### Building JSON Objects and Arrays

```elixir
# Build JSON object
selecto
|> Selecto.select([
    "user.id",
    {:json_build_object, [
      "name", "user.name",
      "email", "user.email",
      "settings", {:json_build_object, [
        "theme", "user.theme",
        "notifications", "user.notifications_enabled"
      ]}
    ], as: "user_profile"}
  ])

# Build JSON array
selecto
|> Selecto.select([
    "product.id",
    {:json_build_array, [
      "product.name",
      "product.category",
      "product.price"
    ], as: "product_data"}
  ])

# Convert row to JSON
selecto
|> Selecto.select([
    {:row_to_json, "product", as: "product_json"},
    {:to_json, "product.tags", as: "tags_json"}
  ])
```

**Generated SQL:**
```sql
-- Build object
SELECT user.id,
       JSON_BUILD_OBJECT(
         'name', user.name,
         'email', user.email,
         'settings', JSON_BUILD_OBJECT(
           'theme', user.theme,
           'notifications', user.notifications_enabled
         )
       ) AS user_profile;

-- Build array
SELECT product.id,
       JSON_BUILD_ARRAY(
         product.name,
         product.category,
         product.price
       ) AS product_data;

-- Row to JSON
SELECT ROW_TO_JSON(product) AS product_json,
       TO_JSON(product.tags) AS tags_json;
```

## JSON Manipulation

### Modifying JSON Data

```elixir
# Set value in JSON
selecto
|> Selecto.select([
    "product.id",
    {:jsonb_set, "product.data", ["price"], "29.99", as: "updated_data"}
  ])

# Set nested value
selecto
|> Selecto.select([
    "config.id",
    {:jsonb_set, "config.settings", 
      ["appearance", "theme"], "\"dark\"", 
      create_missing: true,
      as: "new_settings"}
  ])

# Insert value (won't replace existing)
selecto
|> Selecto.select([
    "user.id",
    {:jsonb_insert, "user.metadata", ["last_login"], "CURRENT_TIMESTAMP", as: "metadata"}
  ])

# Delete field from JSON
selecto
|> Selecto.select([
    "product.id",
    {:jsonb_delete, "product.data", "deprecated_field", as: "cleaned_data"},
    {:jsonb_delete_path, "product.data", ["temp", "cache"], as: "no_cache_data"}
  ])

# Strip nulls from JSON
selecto
|> Selecto.select([
    "response.id",
    {:jsonb_strip_nulls, "response.data", as: "compact_data"}
  ])
```

**Generated SQL:**
```sql
-- Set value
SELECT product.id,
       jsonb_set(product.data, '{price}', '29.99') AS updated_data;

-- Set nested with create_missing
SELECT config.id,
       jsonb_set(config.settings, '{appearance,theme}', '"dark"', true) AS new_settings;

-- Insert value
SELECT user.id,
       jsonb_insert(user.metadata, '{last_login}', 'CURRENT_TIMESTAMP') AS metadata;

-- Delete operations
SELECT product.id,
       product.data - 'deprecated_field' AS cleaned_data,
       product.data #- '{temp,cache}' AS no_cache_data;

-- Strip nulls
SELECT response.id,
       jsonb_strip_nulls(response.data) AS compact_data;
```

### JSON Concatenation and Merging

```elixir
# Concatenate JSON objects (merge)
selecto
|> Selecto.select([
    "user.id",
    {:jsonb_concat, "user.preferences", %{"newsletter" => true}, as: "updated_prefs"}
  ])

# Deep merge with jsonb_set multiple times
selecto
|> Selecto.select([
    "config.id",
    {:jsonb_merge_recursive, "config.base", "config.overrides", as: "final_config"}
  ])
```

## Advanced Patterns

### Complex JSON Queries

#### Searching Nested JSON Arrays

```elixir
# Find products with specific feature
selecto
|> Selecto.select(["product.name", "product.price"])
|> Selecto.filter([
    {:jsonb_path_exists, "product.features", 
      "$[*] ? (@.name == \"waterproof\" && @.value == true)"}
  ])

# Products with price in range
selecto
|> Selecto.select(["product.name"])
|> Selecto.filter([
    {:jsonb_path_exists, "product.data",
      "$ ? (@.price >= 100 && @.price <= 500)"}
  ])
```

#### JSON-based Joins

```elixir
# Join using JSON field
selecto
|> Selecto.select(["order.id", "product.name"])
|> Selecto.join(:inner, "product", 
    on: {:jsonb_contains, "order.items", 
         {:json_build_object, ["product_id", "product.id"]}}
  )

# Join with JSON array elements
selecto
|> Selecto.select(["user.name", "permission.name"])
|> Selecto.join(:cross_lateral,
    {:jsonb_array_elements, "user.permission_ids"}, 
    as: "perm_id"
  )
|> Selecto.join(:inner, "permission", on: "permission.id = perm_id.value")
```

#### Recursive JSON Processing

```elixir
# Extract all values from nested JSON
selecto
|> Selecto.with_recursive_cte("json_values",
    base_query: fn ->
      Selecto.select([
        {:literal, 0, as: "level"},
        "data AS value",
        {:json_typeof, "data", as: "type"}
      ])
      |> Selecto.from("json_table")
    end,
    recursive_query: fn cte ->
      Selecto.select([
        "json_values.level + 1",
        {:case_when, [
          {[{:json_typeof, "json_values.value", "object"}],
           {:jsonb_each, "json_values.value"}},
          {[{:json_typeof, "json_values.value", "array"}],
           {:jsonb_array_elements, "json_values.value"}}
        ], as: "value"},
        {:json_typeof, "value", as: "type"}
      ])
      |> Selecto.from(cte)
      |> Selecto.filter([{:in, {:json_typeof, "json_values.value"}, ["object", "array"]}])
    end
  )
```

### JSON Schema Validation

```elixir
# Validate required fields exist
required_fields = ["name", "email", "age"]

selecto
|> Selecto.select(["user.id", "user.data"])
|> Selecto.filter([
    {:jsonb_has_all_keys, "user.data", required_fields}
  ])

# Validate field types
selecto
|> Selecto.select(["config.id"])
|> Selecto.filter([
    {:and, [
      {:=, {:json_typeof, {:json_get, "config.data", "port"}}, "number"},
      {:=, {:json_typeof, {:json_get, "config.data", "host"}}, "string"},
      {:=, {:json_typeof, {:json_get, "config.data", "ssl"}}, "boolean"}
    ]}
  ])
```

### JSON Transformation Patterns

#### Flattening Nested JSON

```elixir
# Flatten nested object into columns
selecto
|> Selecto.select([
    "product.id",
    {:json_get_text, "product.data", "name", as: "name"},
    {:json_get_text, "product.data", "brand", as: "brand"},
    {:json_get_path_text, "product.data", ["specs", "weight"], as: "weight"},
    {:json_get_path_text, "product.data", ["specs", "dimensions", "width"], as: "width"}
  ])
```

#### Pivoting JSON Arrays

```elixir
# Convert JSON array to columns
selecto
|> Selecto.select([
    "order.id",
    {:json_get_array_element_text, "order.statuses", 0, as: "status_1"},
    {:json_get_array_element_text, "order.statuses", 1, as: "status_2"},
    {:json_get_array_element_text, "order.statuses", 2, as: "status_3"}
  ])
```

## Performance Optimization

### Indexing Strategies

```sql
-- GIN index for containment queries (@>, ?, ?&, ?|)
CREATE INDEX idx_product_data ON products USING GIN (data);

-- GIN with jsonb_path_ops for @> queries only (smaller, faster)
CREATE INDEX idx_order_items ON orders USING GIN (items jsonb_path_ops);

-- B-tree index on extracted value
CREATE INDEX idx_product_category ON products ((data->>'category'));

-- Expression index for nested path
CREATE INDEX idx_product_weight ON products ((data#>>'{specs,weight}'));

-- Partial index for filtered queries
CREATE INDEX idx_active_configs ON configs USING GIN (data) 
WHERE data->>'status' = 'active';
```

### Query Optimization Tips

1. **Use JSONB over JSON**: Binary format is faster for operations
2. **Index appropriately**: GIN for containment, B-tree for specific extractions
3. **Extract frequently**: Create computed columns for often-accessed values
4. **Avoid deep nesting**: Flatten structure when possible
5. **Use jsonb_path_ops**: Smaller index for @> operator only
6. **Validate at write time**: Ensure data consistency on insert/update

### Common Performance Patterns

```elixir
# GOOD: Index-friendly containment query
selecto
|> Selecto.filter([{:jsonb_contains, "data", %{"status" => "active"}}])

# BETTER: Extracted field with B-tree index
selecto
|> Selecto.filter([{"status", "active"}])  # status is extracted column

# GOOD: Using jsonb_path_exists with GIN index
selecto
|> Selecto.filter([{:jsonb_path_exists, "data", "$.tags[*] ? (@ == \"urgent\")"}])

# AVOID: Function calls prevent index usage
selecto
|> Selecto.filter([{:=, {:lower, {:json_get_text, "data", "name"}}, "john"}])
```

## Error Handling

### Common Errors and Solutions

```elixir
# ERROR: cannot extract element from a scalar
# Solution: Check type before extraction
selecto
|> Selecto.select([
    {:case_when, [
      {[{:=, {:json_typeof, "data"}, "object"}],
       {:json_get, "data", "field"}},
      {[true], {:literal, nil}}
    ], as: "safe_extract"}
  ])

# ERROR: cannot extract field from a non-object
# Solution: Ensure value is object type
selecto
|> Selecto.filter([
    {:and, [
      {:=, {:json_typeof, "config"}, "object"},
      {:jsonb_has_key, "config", "setting"}
    ]}
  ])

# ERROR: invalid input syntax for type json
# Solution: Validate JSON before inserting
selecto
|> Selecto.insert(%{
    data: Jason.encode!(%{name: "value"})  # Ensure valid JSON
  })
```

## PostgreSQL Version Compatibility

| Feature | Min Version | Notes |
|---------|-------------|-------|
| Basic JSON type | 9.2+ | Text storage |
| JSONB type | 9.4+ | Binary, indexable |
| jsonb_set | 9.5+ | Modify JSONB |
| jsonb_insert | 11+ | Insert without replace |
| JSONPath | 12+ | SQL/JSON path language |
| JSON subscripting | 14+ | array[index] syntax |

## Best Practices

1. **Choose JSONB**: Unless you need exact formatting preservation
2. **Index strategically**: GIN for searches, B-tree for extractions
3. **Validate structure**: Use CHECK constraints for schema validation
4. **Normalize when needed**: Don't overuse JSON for relational data
5. **Extract hot paths**: Create columns for frequently accessed fields
6. **Batch operations**: Use jsonb_set for multiple updates
7. **Monitor size**: Large JSON documents impact performance

## Use Cases

### Configuration Management

```elixir
# Store and query application configs
selecto
|> Selecto.select([
    "app.name",
    {:json_get_text, "config", "version", as: "version"},
    {:json_get, "config", "features", as: "features"}
  ])
|> Selecto.filter([
    {:jsonb_contains, "config", %{"environment" => "production"}},
    {:jsonb_path_exists, "config", "$.features.authentication"}
  ])
```

### Event Storage

```elixir
# Query event streams
selecto
|> Selecto.select([
    "event.timestamp",
    {:json_get_text, "payload", "user_id", as: "user"},
    {:json_get_text, "payload", "action", as: "action"}
  ])
|> Selecto.filter([
    {:=, {:json_get_text, "payload", "event_type"}, "user_action"},
    {:jsonb_path_exists, "payload", "$.metadata.ip_address"}
  ])
|> Selecto.order_by([{"event.timestamp", :desc}])
```

### Product Catalogs

```elixir
# Flexible product attributes
selecto
|> Selecto.select([
    "product.sku",
    "product.name",
    {:json_get, "attributes", "color", as: "color"},
    {:json_get, "attributes", "size", as: "size"},
    {:json_array_length, {:json_get, "attributes", "tags"}, as: "tag_count"}
  ])
|> Selecto.filter([
    {:jsonb_contains, "attributes", %{"category" => "clothing"}},
    {:jsonb_has_any_key, {:json_get, "attributes", "tags"}, ["sale", "new"]}
  ])
```

## See Also

- [PostgreSQL JSON Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [Array Operations Guide](./array-operations.md)
- [Window Functions Guide](./window-functions.md)
- [Common Table Expressions Guide](./cte.md)