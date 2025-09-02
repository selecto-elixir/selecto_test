# Selecto Implementation Roadmap

## Overview

This document outlines the implementation plan for missing features in Selecto that are documented but not yet implemented. These features are essential for achieving parity with the advanced SQL capabilities described in the documentation.

## Current State Analysis

### Working Features
- Basic query building (`select`, `filter`, `group_by`, `order_by`, `limit`)
- Simple joins
- Basic SQL generation via `Selecto.Builder.Sql`

### Missing Features (Causing Test Failures)
The following features are documented but not implemented, causing 184 test failures:

1. **Array Operations** - `array_select`, `array_filter`, array aggregations
2. **CASE Expressions** - `case_select`, conditional logic in queries
3. **CTEs** - `with_cte`, `with_recursive_cte`
4. **JSON Operations** - JSON/JSONB field operations
5. **LATERAL Joins** - `lateral_join` for correlated subqueries
6. **Parameterized Joins** - Dynamic join conditions
7. **Set Operations** - `union`, `intersect`, `except`
8. **Subqueries/Subfilters** - Nested queries, EXISTS, IN
9. **Subselects** - Aggregated nested data
10. **Window Functions** - Analytical functions

## Implementation Priority

### Phase 1: Core SQL Features (High Priority)
These are fundamental SQL features that many applications need.

#### 1.1 CASE Expressions (2-3 days)
- **Files to modify**: 
  - `vendor/selecto/lib/selecto.ex` - Add `case_select/2` function
  - `vendor/selecto/lib/selecto/builder/case_expression.ex` - New module
  - `vendor/selecto/lib/selecto/builder/sql/select.ex` - Handle CASE in SELECT
- **Implementation approach**:
  ```elixir
  def case_select(selecto, case_spec) do
    # Add CASE expression to select fields
  end
  ```

#### 1.2 Subqueries & EXISTS/IN (3-4 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add subquery functions
  - `vendor/selecto/lib/selecto/builder/subquery.ex` - New module
  - `vendor/selecto/lib/selecto/builder/sql/where.ex` - Handle subqueries in WHERE
- **Implementation approach**:
  ```elixir
  def filter_exists(selecto, subquery_fn)
  def filter_in(selecto, field, subquery_fn)
  ```

#### 1.3 CTEs (Common Table Expressions) (3-4 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add `with_cte/3`, `with_recursive_cte/3`
  - `vendor/selecto/lib/selecto/builder/cte.ex` - New module
  - `vendor/selecto/lib/selecto/builder/sql.ex` - Prepend CTEs to queries
- **Implementation approach**:
  ```elixir
  def with_cte(selecto, name, query_fn) do
    %{selecto | ctes: [{name, query_fn} | selecto.ctes]}
  end
  ```

### Phase 2: Advanced Query Features (Medium Priority)

#### 2.1 Window Functions (4-5 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add window function support
  - `vendor/selecto/lib/selecto/builder/window.ex` - New module
  - `vendor/selecto/lib/selecto/builder/sql/select.ex` - Handle OVER clauses
- **Implementation approach**:
  ```elixir
  def select_window(selecto, {:row_number, over: partition_spec})
  def select_window(selecto, {:rank, over: order_spec})
  ```

#### 2.2 LATERAL Joins (3-4 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add `lateral_join/4`
  - `vendor/selecto/lib/selecto/builder/lateral_join.ex` - Enhance existing
  - `vendor/selecto/lib/selecto/builder/sql/join.ex` - Handle LATERAL keyword
- **Implementation approach**:
  ```elixir
  def lateral_join(selecto, type, subquery_fn, opts) do
    # Build LATERAL join with correlated subquery
  end
  ```

#### 2.3 Set Operations (2-3 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add `union/2`, `intersect/2`, `except/2`
  - `vendor/selecto/lib/selecto/builder/set_operations.ex` - New module
  - `vendor/selecto/lib/selecto/builder/sql.ex` - Handle set operation queries
- **Implementation approach**:
  ```elixir
  def union(selecto1, selecto2) do
    %{selecto1 | set_operation: {:union, selecto2}}
  end
  ```

### Phase 3: Data Type Operations (Lower Priority)

#### 3.1 Array Operations (3-4 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add `array_select/2`, `array_filter/2`
  - `vendor/selecto/lib/selecto/builder/array_operations.ex` - Enhance existing
- **Implementation approach**:
  ```elixir
  def array_select(selecto, array_spec) do
    # Handle ARRAY_AGG, STRING_AGG, etc.
  end
  ```

#### 3.2 JSON Operations (3-4 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add JSON operation functions
  - `vendor/selecto/lib/selecto/builder/json_operations.ex` - New module
- **Implementation approach**:
  ```elixir
  def json_select(selecto, {:json_get, field, path, opts})
  def json_filter(selecto, {:jsonb_contains, field, value})
  ```

### Phase 4: Advanced Features

#### 4.1 Subselects (4-5 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Add `subselect/2`
  - `vendor/selecto/lib/selecto/builder/subselect.ex` - New module
- **Implementation approach**:
  ```elixir
  def subselect(selecto, subselect_spec) do
    # Build correlated subquery with JSON aggregation
  end
  ```

#### 4.2 Parameterized Joins (2-3 days)
- **Files to modify**:
  - `vendor/selecto/lib/selecto.ex` - Enhance join functions
  - `vendor/selecto/lib/selecto/builder/sql/join.ex` - Dynamic join building

## Implementation Guidelines

### 1. API Design Principles
- **Composability**: All functions should return `%Selecto{}` for chaining
- **Consistency**: Similar operations should have similar APIs
- **Type Safety**: Use specs and guards where possible
- **Documentation**: Each function needs @doc and @spec

### 2. Testing Strategy
- Unit tests for each new builder module
- Integration tests using the docs examples
- SQL output validation tests
- Performance benchmarks for complex queries

### 3. Backwards Compatibility
- Don't break existing APIs
- Add new functions rather than modifying existing ones
- Use optional parameters for new features

### 4. Code Structure
```
vendor/selecto/lib/selecto/
├── builder/
│   ├── array_operations.ex     # Enhanced
│   ├── case_expression.ex      # New
│   ├── cte.ex                  # New
│   ├── json_operations.ex      # New
│   ├── lateral_join.ex         # Enhanced
│   ├── set_operations.ex       # New
│   ├── subquery.ex             # New
│   ├── subselect.ex            # New
│   └── window.ex               # New
└── builder/sql/
    ├── select.ex               # Enhanced for new features
    ├── where.ex                # Enhanced for subqueries
    └── join.ex                 # Enhanced for LATERAL

```

## Estimated Timeline

- **Phase 1**: 8-11 days (Critical for basic SQL completeness)
- **Phase 2**: 9-12 days (Important for analytical queries)
- **Phase 3**: 6-8 days (Nice to have for specific use cases)
- **Phase 4**: 6-8 days (Advanced features)

**Total**: 29-39 days of development

## Next Steps

1. **Immediate** (Week 1):
   - Implement CASE expressions
   - Add basic subquery support
   - Start CTE implementation

2. **Short-term** (Weeks 2-3):
   - Complete CTEs including recursive
   - Implement window functions
   - Add LATERAL join support

3. **Medium-term** (Weeks 4-5):
   - Set operations
   - Array and JSON operations
   - Subselects

4. **Long-term** (Week 6+):
   - Parameterized joins
   - Performance optimizations
   - Additional helper functions

## Success Metrics

- All 184 failing tests pass
- Documentation examples work as written
- Performance benchmarks show < 10% overhead vs raw SQL
- API is intuitive and well-documented

## Risk Mitigation

- **Risk**: Breaking changes to existing API
  - **Mitigation**: Comprehensive test suite before changes
  
- **Risk**: Performance degradation
  - **Mitigation**: Benchmark critical paths
  
- **Risk**: SQL injection vulnerabilities
  - **Mitigation**: Proper parameterization, security review

## Dependencies

- PostgreSQL 12+ for advanced SQL features
- Ecto 3.0+ for schema integration
- Comprehensive test database with sample data

## Notes

- Consider creating a `selecto_extensions` package for very advanced features
- Some features might require PostgreSQL-specific syntax
- Performance should be prioritized for common operations