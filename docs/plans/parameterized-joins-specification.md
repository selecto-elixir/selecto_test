# Parameterized Joins and Dot Notation Specification

## Overview

This specification defines the implementation of parameterized joins with dot notation syntax for the Selecto ecosystem. This enhancement will replace the existing bracket notation (`table[field]`) with a more intuitive dot notation (`table.field`) and introduce parameterized joins with colon-separated parameters.

## Current State Analysis

### Existing Bracket Notation
- Field references: `"join[field]"` format
- SQL generation uses `build_selector_string(_selecto, join, field)` → `"join"."field"`
- Field resolution in `FieldResolver.extract_field_name/1` handles `[field]` extraction
- Custom columns use bracket notation for selects: `"#{association.field}[#{config.dimension}]"`

### Existing Join System
- Join definitions in domain `joins: %{join_name => config}`
- Join processing in `Selecto.Schema.Join.recurse_joins/2`
- SQL generation in `Selecto.Builder.Sql.build_enhanced_join/7`

## New Parameterized Join Syntax

### Basic Syntax
```elixir
# Old bracket notation (backward compatible)
"posts[title]"
"category[name]"

# New dot notation
"posts.title"
"category.name"

# Parameterized joins with single parameter
"posts:published.title"        # posts join with "published" parameter
"category:electronics.name"    # category join with "electronics" parameter

# Parameterized joins with multiple parameters
"posts:published:featured.title"      # posts join with "published" and "featured" parameters
"discounts:seasonal:premium.amount"   # discounts join with "seasonal" and "premium" parameters
```

### Parameter Types and Quoting Rules

#### Unquoted Parameters (Simple identifiers)
- Must contain only `\w` characters (letters, digits, underscore)
- Examples: `posts:published`, `category:electronics`, `users:active`

#### Quoted Parameters (Complex values)
- Single quotes for strings with special characters: `posts:'special-category'`  
- Double quotes for strings in contexts requiring them: `posts:"user role"`
- Numeric literals: `posts:1`, `discounts:50.5`, `items:true`

#### Parameter Type Examples
```elixir
# String parameters
"products:electronics.name"           # unquoted string
"products:'special-category'.name"    # quoted string with special chars
"products:\"user category\".name"     # quoted string with spaces

# Numeric parameters  
"discounts:50.amount"                 # integer
"rates:12.5.percentage"               # float

# Boolean parameters
"users:true.name"                     # boolean true
"users:false.name"                    # boolean false

# Multiple mixed parameters
"products:electronics:50:true.name"   # string:integer:boolean
"rates:'special-offer':12.5.amount"   # quoted-string:float
```

## Join Configuration Schema

### Domain Configuration
```elixir
joins: %{
  # Simple non-parameterized join (existing behavior)
  posts: %{
    type: :left,
    name: "Posts"
  },
  
  # Parameterized join definition
  products: %{
    type: :left,
    name: "Products",
    parameters: [
      # Parameter with type validation
      %{
        name: :category,
        type: :string,
        required: true,
        description: "Product category filter"
      },
      %{
        name: :min_price, 
        type: :float,
        required: false,
        default: 0.0,
        description: "Minimum price threshold"
      },
      %{
        name: :active,
        type: :boolean,
        required: false,
        default: true,
        description: "Include only active products"
      }
    ]
  },

  # Advanced parameterized join with custom SQL
  discounts: %{
    type: :left,
    name: "Discounts",
    parameters: [
      %{name: :season, type: :string, required: true},
      %{name: :tier, type: :string, required: false, default: "standard"}
    ],
    # Custom join condition template using parameters
    join_condition: """
    {join_alias}.product_id = {parent_alias}.id AND
    {join_alias}.season = $param_season AND
    {join_alias}.tier = $param_tier AND
    {join_alias}.active = true
    """
  }
}
```

### Runtime Parameter Resolution
```elixir
# During field resolution, parameters are extracted and validated
selecto = Selecto.new(domain, postgrex_opts)
  |> Selecto.select(["products:electronics:25.0:true.name", "products:electronics:25.0:true.price"])
  |> Selecto.run()

# Parameters are validated against join definitions:
# - :category = "electronics" (string, valid)  
# - :min_price = 25.0 (float, valid)
# - :active = true (boolean, valid)
```

## Implementation Architecture

### Core Components to Update

#### 1. Field Parser Enhancement (`Selecto.FieldResolver`)
```elixir
defmodule Selecto.FieldResolver.ParameterizedParser do
  @doc "Parse field references with parameterized joins"
  def parse_field_reference(field_ref) do
    case String.split(field_ref, ".") do
      [join_with_params, field] ->
        {join_name, parameters} = parse_join_with_parameters(join_with_params)
        {:ok, %{type: :parameterized, join: join_name, field: field, parameters: parameters}}
      [field] ->
        {:ok, %{type: :simple, field: field}}
    end
  end

  defp parse_join_with_parameters(join_string) do
    case String.split(join_string, ":") do
      [join_name] -> {join_name, []}
      [join_name | params] -> {join_name, parse_parameters(params)}
    end
  end

  defp parse_parameters(params) do
    Enum.map(params, &parse_single_parameter/1)
  end

  defp parse_single_parameter(param) do
    cond do
      # Boolean literals
      param == "true" -> {:boolean, true}
      param == "false" -> {:boolean, false}
      
      # Numeric literals
      String.match?(param, ~r/^\d+\.\d+$/) -> 
        {:float, String.to_float(param)}
      String.match?(param, ~r/^\d+$/) -> 
        {:integer, String.to_integer(param)}
        
      # Quoted strings
      String.starts_with?(param, "'") && String.ends_with?(param, "'") ->
        {:string, String.slice(param, 1..-2)}
      String.starts_with?(param, "\"") && String.ends_with?(param, "\"") ->
        {:string, String.slice(param, 1..-2)}
        
      # Unquoted identifiers
      String.match?(param, ~r/^\w+$/) ->
        {:string, param}
        
      # Error case
      true -> {:error, "Invalid parameter format: #{param}"}
    end
  end
end
```

#### 2. Join Configuration Processor
```elixir
defmodule Selecto.Schema.ParameterizedJoin do
  def process_parameterized_join(join_id, join_config, parameters, parent, from_source, queryable) do
    # Validate parameters against join definition
    validated_params = validate_parameters(join_config.parameters || [], parameters)
    
    # Build join with parameter context
    base_join = configure_base_join(join_id, join_config, parent, from_source, queryable)
    
    %{base_join | 
      parameters: validated_params,
      parameter_context: build_parameter_context(validated_params),
      join_condition: resolve_parameterized_condition(join_config, validated_params)
    }
  end

  defp validate_parameters(param_definitions, provided_params) do
    # Match provided parameters with definitions, apply defaults, validate types
    Enum.map(param_definitions, fn definition ->
      provided_value = find_parameter_value(provided_params, definition.name)
      validated_value = validate_parameter_type(provided_value, definition)
      %{name: definition.name, value: validated_value, type: definition.type}
    end)
  end
end
```

#### 3. SQL Generation Enhancement
```elixir
defmodule Selecto.Builder.Sql.ParameterizedJoin do
  def build_parameterized_join_sql(selecto, join, config, join_type, fc, p, ctes) do
    # Build base join SQL
    base_sql = build_base_join_sql(selecto, join, config, join_type, fc, p, ctes)
    
    # Apply parameter-specific conditions
    parameterized_sql = apply_parameter_conditions(base_sql, join.parameters, join.parameter_context)
    
    # Add parameter values to query parameter list
    updated_params = add_join_parameters_to_query(p, join.parameters)
    
    {parameterized_sql, updated_params}
  end

  defp apply_parameter_conditions(base_sql, parameters, parameter_context) do
    # Replace parameter placeholders in join conditions
    Enum.reduce(parameters, base_sql, fn param, sql ->
      placeholder = "$param_#{param.name}"
      String.replace(sql, placeholder, parameter_placeholder(param))
    end)
  end
end
```

## Backward Compatibility Strategy

### Phase 1: Dual Support (Months 1-2)
- Both bracket `"table[field]"` and dot `"table.field"` notation supported
- Existing field resolution unchanged
- New parameterized syntax available alongside existing

### Phase 2: Deprecation Warnings (Month 3)
- Bracket notation generates deprecation warnings
- Documentation updated to promote dot notation
- Migration tools provided

### Phase 3: Full Migration (Months 4-6)
- Bracket notation support maintained but discouraged
- All examples and documentation use dot notation
- Legacy support remains for existing codebases

## Database Schema Extensions

### Test Data for Parameterized Joins
```sql
-- Product categories for parameterized testing
CREATE TABLE product_categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  parent_id INTEGER REFERENCES product_categories(id),
  active BOOLEAN DEFAULT true
);

-- Seasonal discounts for multi-parameter testing
CREATE TABLE seasonal_discounts (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL,
  season VARCHAR(20) NOT NULL, -- spring, summer, fall, winter
  tier VARCHAR(20) NOT NULL,   -- standard, premium, vip
  discount_percent DECIMAL(5,2) NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- User preferences for boolean parameter testing
CREATE TABLE user_preferences (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  preference_key VARCHAR(100) NOT NULL,
  preference_value JSONB,
  is_active BOOLEAN DEFAULT true
);
```

## Testing Strategy

### Unit Test Categories

#### 1. Parameter Parsing Tests
```elixir
defmodule Selecto.FieldResolver.ParameterizedParserTest do
  test "parses simple dot notation" do
    assert {:ok, %{type: :qualified, join: "posts", field: "title"}} = 
           parse_field_reference("posts.title")
  end

  test "parses single parameter" do
    assert {:ok, %{type: :parameterized, join: "posts", field: "title", parameters: ["published"]}} = 
           parse_field_reference("posts:published.title")
  end

  test "parses multiple mixed parameters" do
    assert {:ok, %{parameters: [
      {:string, "electronics"}, 
      {:float, 25.0}, 
      {:boolean, true}
    ]}} = parse_field_reference("products:electronics:25.0:true.name")
  end
end
```

#### 2. SQL Generation Tests  
```elixir
test "generates parameterized join SQL" do
  selecto = build_test_selecto_with_parameterized_joins()
  query = Selecto.select(selecto, ["products:electronics:25.0.name"])
  
  {sql, params} = Selecto.Builder.Sql.build_sql(query)
  
  assert sql =~ "LEFT JOIN products ON products.category = $1 AND products.min_price >= $2"
  assert params == ["electronics", 25.0]
end
```

#### 3. Integration Tests
```elixir
test "end-to-end parameterized join query" do
  result = 
    build_test_selecto()
    |> Selecto.select(["products:electronics:50.0:true.name", "products:electronics:50.0:true.price"])
    |> Selecto.filter("products:electronics:50.0:true.active", true)
    |> Selecto.run()
  
  assert length(result) > 0
  assert Enum.all?(result, fn row -> 
    row["products:electronics:50.0:true.name"] && row["products:electronics:50.0:true.price"]
  end)
end
```

## Performance Considerations

### Query Optimization
- Parameter validation cached per join configuration
- SQL generation optimized for common parameter patterns
- Join condition templates pre-compiled where possible

### Memory Usage
- Parameter contexts shared across similar field references
- Lazy evaluation of complex parameter combinations

## Migration Guide

### Automatic Migration Tools
```bash
# SelectoMix task to migrate existing domains
mix selecto.migrate.dot_notation --path lib/domains/
mix selecto.migrate.dot_notation --dry-run --verbose

# Output:
# Migrating: posts[title] → posts.title
# Migrating: category[name] → category.name  
# Found 45 field references to migrate
```

### Manual Migration Examples
```elixir
# Before
joins: %{
  posts: %{type: :left}
}
selected: ["posts[title]", "posts[created_at]"]

# After
joins: %{
  posts: %{type: :left}
}
selected: ["posts.title", "posts.created_at"]

# Advanced: Converting to parameterized joins
joins: %{
  posts: %{
    type: :left,
    parameters: [
      %{name: :status, type: :string, required: false, default: "published"}
    ]
  }
}
selected: ["posts:published.title"]
```

## Error Handling

### Parameter Validation Errors
```elixir
# Type mismatch
{:error, "Parameter 'min_price' expects :float, got :string 'invalid'"}

# Missing required parameter
{:error, "Required parameter 'category' missing for join 'products'"}

# Invalid parameter format
{:error, "Invalid parameter format: 'invalid-chars!' for join 'products'"}
```

### Runtime Errors
```elixir
# Join not found
{:error, "Parameterized join 'unknown_join:param' not found"}

# Field not found in parameterized join
{:error, "Field 'invalid_field' not found in parameterized join 'products:electronics'"}
```

## Future Extensions

### Dynamic Parameter Resolution
```elixir
# Runtime parameter injection
selecto
|> Selecto.with_join_parameters("products", %{category: user_category, min_price: user_budget})
|> Selecto.select(["products:#{user_category}:#{user_budget}.name"])
```

### Parameter Inheritance
```elixir
# Nested joins inherit parent parameters
joins: %{
  categories: %{
    parameters: [%{name: :active, type: :boolean, default: true}],
    joins: %{
      products: %{
        # Inherits :active parameter from parent
        inherit_parameters: [:active]
      }
    }
  }
}
```

This specification provides a comprehensive foundation for implementing parameterized joins with dot notation while maintaining full backward compatibility and providing a clear migration path.