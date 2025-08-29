# Advanced SQL Features Implementation Plan

## Overview

This plan outlines Phase 4 of the Selecto roadmap, implementing advanced PostgreSQL features that extend beyond standard SQL operations. These features enable sophisticated data manipulation patterns, dynamic query construction, and modern JSON-based workflows.

Building on the completed foundational phases (Parameterized Joins, Output Formats, Subfilters, Window Functions, Set Operations), this phase adds enterprise-grade SQL capabilities while maintaining Selecto's characteristic ease of use and type safety.

## Target Features

### 1. LATERAL Joins
Advanced join capability where the right side can reference columns from the left side, enabling correlated subqueries in join clauses.

### 2. VALUES Clauses
Construct inline tables from literal values, useful for data transformations and testing scenarios.

### 3. JSON Operations
Comprehensive PostgreSQL JSON/JSONB support including path queries, aggregation, and manipulation functions.

### 4. Common Table Expressions (CTEs)
Recursive and non-recursive WITH clauses for hierarchical queries and query modularity.

### 5. CASE Expressions
Conditional logic within SELECT statements for data transformation.

### 6. Array Operations
PostgreSQL array functions for list manipulation and aggregation.

## Implementation Strategy

### Phase 4.1: LATERAL Joins (2 weeks) ✅ COMPLETED

#### API Design
```elixir
# LATERAL join with correlated subquery
selecto
|> Selecto.select(["customer.name", "recent_rentals.rental_count"])
|> Selecto.lateral_join(
  :left,
  fn base_query ->
    Selecto.configure(rental_domain, connection)
    |> Selecto.select([{:func, "COUNT", ["*"], as: "rental_count"}])
    |> Selecto.filter([{"customer_id", {:ref, "customer.customer_id"}}])
    |> Selecto.filter([{"rental_date", {:>, {:func, "CURRENT_DATE - INTERVAL '30 days'"}}}])
  end,
  as: "recent_rentals"
)

# Generated SQL:
# SELECT customer.name, recent_rentals.rental_count
# FROM customer
# LEFT JOIN LATERAL (
#   SELECT COUNT(*) as rental_count
#   FROM rental 
#   WHERE customer_id = customer.customer_id 
#     AND rental_date > CURRENT_DATE - INTERVAL '30 days'
# ) recent_rentals ON true
```

#### Implementation Components ✅ ALL COMPLETED
- ✅ **Lateral Join Spec**: Define correlation references and subquery builders
- ✅ **SQL Generation**: Handle LATERAL keyword and correlation resolution
- ✅ **Validation**: Ensure referenced columns exist in left-side tables
- ✅ **Testing**: Complex correlation scenarios and edge cases

**Status**: Fully implemented with comprehensive test coverage (15/15 tests passing). Production-ready.

### Phase 4.2: VALUES Clauses (1.5 weeks) ✅ COMPLETED

#### API Design
```elixir
# VALUES table for data transformation
values_data = [
  ["PG", "Family Friendly", 1],
  ["PG-13", "Teen", 2], 
  ["R", "Adult", 3],
  ["NC-17", "Restricted", 4]
]

selecto
|> Selecto.with_values(values_data, 
    columns: ["rating_code", "description", "sort_order"],
    as: "rating_lookup"
  )
|> Selecto.join(:inner, "film.rating = rating_lookup.rating_code")
|> Selecto.select(["film.title", "rating_lookup.description"])
|> Selecto.order_by([{"rating_lookup.sort_order", :asc}])

# Generated SQL:
# WITH rating_lookup (rating_code, description, sort_order) AS (
#   VALUES ('PG', 'Family Friendly', 1),
#          ('PG-13', 'Teen', 2),
#          ('R', 'Adult', 3), 
#          ('NC-17', 'Restricted', 4)
# )
# SELECT film.title, rating_lookup.description
# FROM film
# INNER JOIN rating_lookup ON film.rating = rating_lookup.rating_code
# ORDER BY rating_lookup.sort_order ASC
```

#### Implementation Components
- **Values Spec**: Define column mappings and data validation
- **SQL Generation**: VALUES clause construction with proper escaping
- **Type Inference**: Automatic type detection from data
- **CTE Integration**: Seamless integration with Common Table Expressions

### Phase 4.3: JSON Operations (2.5 weeks) ✅ COMPLETED

#### API Design
```elixir
# JSON path queries and operations
selecto
|> Selecto.select([
    "product.name",
    {:json_extract, "metadata", "$.category", as: "category"},
    {:json_extract, "metadata", "$.specs.weight", as: "weight"},
    {:json_array_length, "tags", as: "tag_count"}
  ])
|> Selecto.filter([
    {:json_contains, "metadata", %{"category" => "electronics"}},
    {:json_path_exists, "metadata", "$.specs.warranty"}
  ])
|> Selecto.order_by([{:json_extract, "metadata", "$.priority"}])

# Advanced JSON aggregation
selecto
|> Selecto.select([
    "category",
    {:json_agg, "product_name", as: "products"},
    {:json_object_agg, "product_id", "price", as: "price_map"}
  ])
|> Selecto.group_by(["category"])

# Generated SQL:
# SELECT category,
#        JSON_AGG(product_name) as products,
#        JSON_OBJECT_AGG(product_id, price) as price_map
# FROM products
# GROUP BY category
```

#### Implementation Components ✅ ALL COMPLETED
- ✅ **JSON Operations Spec**: Comprehensive operation types and validation
- ✅ **SQL Generation**: PostgreSQL-specific JSON/JSONB function calls
- ✅ **API Integration**: json_select, json_filter, json_order_by methods
- ✅ **Pipeline Integration**: SELECT, WHERE, ORDER BY clause support

#### JSON Function Coverage ✅ IMPLEMENTED
- **Extraction**: `->`, `->>`, `json_extract_path`, `json_extract_path_text`
- **Testing**: `@>`, `<@`, `?`, `json_exists`, `jsonb_path_exists`
- **Aggregation**: `json_agg`, `json_object_agg`, `jsonb_agg`, `jsonb_object_agg`
- **Construction**: `json_build_object`, `json_build_array`, `jsonb_build_object`, `jsonb_build_array`
- **Manipulation**: `json_set`, `jsonb_set`, `json_insert`, `jsonb_insert`
- **Type Operations**: `json_typeof`, `jsonb_typeof`, `json_array_length`, `jsonb_array_length`

**Status**: Fully implemented with comprehensive PostgreSQL JSON/JSONB support. Production-ready.

### Phase 4.4: Common Table Expressions (2 weeks) ✅ COMPLETED

#### API Design
```elixir
# Non-recursive CTE
selecto
|> Selecto.with_cte("high_value_customers", fn ->
    Selecto.configure(customer_domain, connection)
    |> Selecto.select(["customer_id", "first_name", "last_name"])
    |> Selecto.aggregate([{"payment.amount", :sum, as: "total_spent"}])
    |> Selecto.join(:inner, "payment", on: "customer.customer_id = payment.customer_id")
    |> Selecto.group_by(["customer.customer_id", "customer.first_name", "customer.last_name"])
    |> Selecto.having([{"total_spent", {:>, 100}}])
  end)
|> Selecto.select(["film.title", "high_value_customers.first_name"])
|> Selecto.join(:inner, "high_value_customers", 
    on: "rental.customer_id = high_value_customers.customer_id")

# Recursive CTE for hierarchical data
selecto
|> Selecto.with_recursive_cte("org_hierarchy", 
    base_query: fn ->
      # Anchor: top-level managers
      Selecto.configure(employee_domain, connection)
      |> Selecto.select(["employee_id", "name", "manager_id", {:literal, 0, as: "level"}])
      |> Selecto.filter([{"manager_id", nil}])
    end,
    recursive_query: fn cte ->
      # Recursive: employees under each manager
      Selecto.configure(employee_domain, connection)
      |> Selecto.select(["employee.employee_id", "employee.name", "employee.manager_id", 
                        {:func, "org_hierarchy.level + 1", as: "level"}])
      |> Selecto.join(:inner, cte, on: "employee.manager_id = org_hierarchy.employee_id")
    end
  )
```

#### Implementation Components ✅ ALL COMPLETED
- ✅ **CTE Specification**: Comprehensive CTE definitions with validation
- ✅ **SQL Generation**: WITH clause construction with dependency ordering
- ✅ **Recursive Support**: UNION ALL handling for recursive patterns with base/recursive queries
- ✅ **API Integration**: with_cte, with_recursive_cte, and with_ctes methods
- ✅ **Pipeline Integration**: Full integration with main SQL building pipeline
- ✅ **Dependency Management**: Circular dependency detection and CTE ordering

**Status**: Fully implemented with comprehensive PostgreSQL CTE support including recursive CTEs. Production-ready.

### Phase 4.5: CASE Expressions (1 week) ✅ COMPLETED

#### API Design
```elixir
# Simple CASE expression
selecto
|> Selecto.select([
    "film.title",
    {:case, "film.rating",
      when: [
        {"G", "General Audience"},
        {"PG", "Parental Guidance"},
        {"PG-13", "Parents Strongly Cautioned"},
        {"R", "Restricted"}
      ],
      else: "Not Rated",
      as: "rating_description"
    }
  ])

# Searched CASE expression
selecto
|> Selecto.select([
    "customer.first_name",
    {:case_when, [
        {[{"payment_total", {:>, 100}}], "Premium"},
        {[{"payment_total", {:between, 50, 100}}], "Standard"},
        {[{"payment_total", {:>, 0}}], "Basic"}
      ],
      else: "No Purchases",
      as: "customer_tier"
    }
  ])

# Generated SQL:
# SELECT customer.first_name,
#        CASE 
#          WHEN payment_total > 100 THEN 'Premium'
#          WHEN payment_total BETWEEN 50 AND 100 THEN 'Standard'
#          WHEN payment_total > 0 THEN 'Basic'
#          ELSE 'No Purchases'
#        END as customer_tier
```

#### Implementation Components ✅ ALL COMPLETED
- ✅ **CASE Expression Specification**: Comprehensive CASE specification with validation
- ✅ **SQL Generation**: PostgreSQL CASE syntax with proper parameter binding
- ✅ **API Integration**: case_select and case_when_select methods
- ✅ **Pipeline Integration**: SELECT clause support with aliasing
- ✅ **Validation System**: Type checking and format validation for CASE expressions

#### CASE Expression Coverage ✅ IMPLEMENTED
- **Simple CASE**: Column-based CASE expressions with value matching
- **Searched CASE**: Condition-based CASE expressions with complex logic
- **Multiple Conditions**: Support for multiple conditions per WHEN clause
- **Parameter Binding**: Safe parameter handling for values and conditions
- **Aliasing**: AS clause support for CASE expression results
- **Null Handling**: Proper NULL value handling in CASE expressions

**Status**: Fully implemented with comprehensive PostgreSQL CASE expression support. Production-ready.

### Phase 4.6: Array Operations (1.5 weeks) ✅ COMPLETED

#### API Design  
```elixir
# Array construction and operations
selecto
|> Selecto.select([
    "category.name",
    {:array_agg, "film.title", as: "films"},
    {:array_length, {:array_agg, "film.film_id"}, 1, as: "film_count"}
  ])
|> Selecto.filter([
    {:array_contains, "film.special_features", "Trailers"},
    {:array_overlap, "film.special_features", ["Deleted Scenes", "Behind the Scenes"]}
  ])
|> Selecto.group_by(["category.category_id", "category.name"])

# Array unnesting
selecto
|> Selecto.select(["film.title", "feature"])
|> Selecto.unnest("film.special_features", as: "feature")
|> Selecto.order_by(["film.title", "feature"])

# Generated SQL:
# SELECT film.title, feature
# FROM film, UNNEST(film.special_features) AS feature
# ORDER BY film.title, feature
```

#### Implementation Components ✅ ALL COMPLETED
- ✅ **Array Operations Spec**: Comprehensive specification module with validation
- ✅ **SQL Builder**: Full PostgreSQL array SQL generation with parameter binding
- ✅ **API Methods**: array_select, array_filter, unnest, array_manipulate
- ✅ **Pipeline Integration**: Integrated into SELECT, WHERE, and FROM clauses
- ✅ **Test Coverage**: Unit tests for all array operations and SQL generation

#### Array Function Coverage ✅ IMPLEMENTED
- **Aggregation**: `array_agg`, `array_agg_distinct`, `string_agg`
- **Testing**: `@>`, `<@`, `&&`, `=` (contains, contained, overlap, equality)
- **Size**: `array_length`, `cardinality`, `array_ndims`, `array_dims`
- **Construction**: `array`, `array_fill`, `array_append`, `array_prepend`, `array_cat`
- **Manipulation**: `array_remove`, `array_replace`, `array_position`, `array_positions`
- **Transformation**: `unnest`, `array_to_string`, `string_to_array`
- **Set Operations**: `array_union`, `array_intersect`, `array_except` (PG 14+)

**Status**: Fully implemented with comprehensive PostgreSQL array support. Production-ready.

## Architecture Integration

### Module Structure
```
vendor/selecto/lib/selecto/advanced/
├── lateral_join.ex                 # LATERAL join specifications
├── values_clause.ex               # VALUES table construction  
├── json_operations.ex             # JSON function definitions
├── cte.ex                         # Common Table Expression specs
├── case_expression.ex             # CASE/WHEN logic
└── array_operations.ex            # Array function support

vendor/selecto/lib/selecto/builder/advanced/
├── lateral_join_builder.ex        # LATERAL SQL generation
├── values_builder.ex              # VALUES SQL generation
├── json_builder.ex                # JSON SQL generation
├── cte_builder.ex                 # CTE SQL generation
├── case_builder.ex                # CASE SQL generation
└── array_builder.ex               # Array SQL generation
```

### SQL Pipeline Integration
Advanced features integrate into the main SQL generation pipeline:

1. **CTEs**: Generated first in WITH clauses
2. **VALUES**: Integrated as CTE or subquery sources
3. **LATERAL**: Enhanced join builder with correlation support
4. **JSON/Array/CASE**: Enhanced column selection and filtering
5. **Parameter Binding**: Advanced parameter handling for complex expressions

## Testing Strategy

### Unit Tests
- Individual feature API testing
- SQL generation verification
- Parameter binding validation
- Error condition handling

### Integration Tests
- Cross-feature compatibility (CTE + LATERAL + JSON)
- Complex real-world scenarios
- Performance benchmarking
- Memory usage profiling

### Test Data Scenarios
- **Hierarchical Data**: Employee org charts, category trees
- **JSON Documents**: Product catalogs, user preferences
- **Array Data**: Tags, features, multi-value attributes
- **Correlation Patterns**: Customer analytics, time-series analysis

## Performance Considerations

### Query Optimization
- **LATERAL Join Strategies**: When to use vs. EXISTS/correlated subqueries
- **CTE Materialization**: PostgreSQL CTE optimization behavior
- **JSON Indexing**: GIN index recommendations for JSONB operations
- **Array Performance**: Index strategies for array containment queries

### Memory Management
- **Large VALUES**: Streaming support for big inline datasets
- **Deep CTEs**: Recursive query depth limitations
- **JSON Processing**: Memory-efficient JSON aggregation
- **Complex Expressions**: Compilation and caching strategies

## Error Handling & Validation

### Advanced Validation Rules
- **LATERAL Correlations**: Validate referenced columns exist
- **CTE Dependencies**: Detect circular references
- **JSON Paths**: Validate JSONPath syntax
- **Recursive Limits**: Prevent infinite recursion

### Error Messages
- Clear guidance for complex SQL errors
- Suggestions for query optimization
- Performance warnings for expensive operations

## Migration & Compatibility

### Breaking Changes
- None expected - all features are additive
- New API methods with optional parameters
- Backward compatible SQL generation

### PostgreSQL Version Support
- **Minimum**: PostgreSQL 10 (for improved JSON support)
- **Recommended**: PostgreSQL 13+ (for advanced JSON path queries)
- **Feature Flags**: Graceful degradation for unsupported features

## Documentation Requirements

### API Documentation
- [ ] Comprehensive function documentation with examples
- [ ] Performance guidelines for each feature
- [ ] PostgreSQL version compatibility matrix
- [ ] Common patterns and anti-patterns guide

### Tutorial Content
- [ ] LATERAL joins vs. correlated subqueries guide
- [ ] JSON querying and indexing best practices
- [ ] Recursive CTE patterns for hierarchical data
- [ ] Advanced data transformation recipes

### Migration Guides
- [ ] Converting complex raw SQL to Selecto advanced features
- [ ] Performance optimization techniques
- [ ] Debugging complex queries

## Success Metrics

### Feature Completeness
- [ ] All major PostgreSQL advanced features supported
- [ ] 100% API compatibility with existing Selecto patterns
- [ ] Comprehensive test coverage (>95%)
- [ ] Zero performance regression on existing queries

### Performance Targets
- [ ] LATERAL joins within 10% of hand-written SQL performance
- [ ] JSON operations support for documents up to 10MB
- [ ] CTE recursion depth support up to 1000 levels
- [ ] Array operations efficient for arrays up to 10,000 elements

### Developer Experience
- [ ] Intuitive API consistent with existing Selecto patterns
- [ ] Clear error messages for complex scenarios
- [ ] Comprehensive examples for all major use cases
- [ ] Production deployment validation

## Future Enhancements

### Advanced PostgreSQL Features
- [ ] **Window Function Extensions**: FILTER clauses, custom aggregates
- [ ] **Advanced Text Search**: Full-text search integration
- [ ] **Geometric Operations**: PostGIS-style spatial queries
- [ ] **Custom Functions**: User-defined function integration

### Query Analysis & Optimization
- [ ] **Query Plan Analysis**: EXPLAIN integration and optimization hints
- [ ] **Performance Monitoring**: Query performance tracking
- [ ] **Auto-Optimization**: Automatic query rewriting suggestions
- [ ] **Index Recommendations**: Smart indexing suggestions

### Developer Tooling
- [ ] **Visual Query Builder**: UI for complex query construction
- [ ] **Query Debugger**: Step-through query execution
- [ ] **Performance Profiler**: Detailed performance analysis
- [ ] **Schema Inspector**: Advanced schema exploration tools

This Advanced SQL Features implementation establishes Selecto as a comprehensive PostgreSQL query builder capable of handling the most sophisticated analytical and data manipulation scenarios while maintaining its core principles of type safety and developer productivity.