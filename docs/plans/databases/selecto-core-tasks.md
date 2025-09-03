# Selecto Core - Universal Database Support Task List

**Repository:** `vendor/selecto/`  
**Priority:** Critical  
**Estimated Effort:** 4-5 weeks (Core only, adapters developed separately)

## Phase 1: Core Infrastructure (Week 1-2)

### 1.1 Adapter System Foundation
- [ ] Create `lib/selecto/database/adapter.ex` with behavior definition
- [ ] Create `lib/selecto/database/registry.ex` for dynamic adapter registration
- [ ] Create `lib/selecto/database/dialect.ex` base module for SQL dialects
- [ ] Create `lib/selecto/database/features.ex` for capability detection
- [ ] Create `lib/selecto/database/types.ex` for type system interface
- [ ] Create `lib/selecto/database/adapter_loader.ex` for loading external adapters
- [ ] Write comprehensive tests for adapter behavior

### 1.2 Connection Abstraction
- [ ] Create `lib/selecto/connection.ex` unified connection interface
- [ ] Modify `lib/selecto.ex` struct to add `adapter` field (keep `postgrex_opts` for compatibility)
- [ ] Update `configure/3` to accept `:adapter` option
- [ ] Create adapter discovery mechanism for installed packages
- [ ] Maintain 100% backward compatibility with existing PostgreSQL code
- [ ] Add connection pooling abstraction interface

### 1.3 Query Translation Layer
- [ ] Create `lib/selecto/database/query_translator.ex`
- [ ] Implement parameter binding translation (numbered, question, named)
- [ ] Implement identifier quoting for different databases
- [ ] Create SQL dialect transformation rules
- [ ] Build feature detection and emulation system
- [ ] Add query optimization hints per database

## Phase 2: SQL Generation Updates (Week 3-4)

### 2.1 Modify SQL Builders
- [ ] Update `lib/selecto/builder/sql.ex` to be dialect-aware
- [ ] Modify `lib/selecto/builder/sql/select.ex` for database-specific SELECT
- [ ] Update `lib/selecto/builder/sql/where.ex` for different comparison operators
- [ ] Modify `lib/selecto/builder/sql/join.ex` for database-specific joins
- [ ] Update `lib/selecto/builder/sql/group.ex` for ROLLUP/CUBE differences
- [ ] Modify `lib/selecto/builder/sql/order.ex` for NULL ordering differences

### 2.2 Feature-Specific Builders
- [ ] Update `lib/selecto/builder/window.ex` for window function compatibility
- [ ] Modify `lib/selecto/builder/cte.ex` for CTE support detection
- [ ] Update `lib/selecto/builder/pivot.ex` for database-specific pivot
- [ ] Modify `lib/selecto/builder/set_operations.ex` for UNION/EXCEPT differences
- [ ] Update `lib/selecto/builder/json_operations.ex` for JSON support

### 2.3 Advanced Features
- [ ] Update `lib/selecto/advanced/lateral_join.ex` for CROSS APPLY (SQL Server)
- [ ] Modify `lib/selecto/advanced/array_operations.ex` for array handling
- [ ] Update `lib/selecto/advanced/hierarchical.ex` for recursive queries
- [ ] Add fulltext search abstraction for different implementations
- [ ] Create temporal/time-series abstractions

## Phase 3: Executor Updates (Week 3)

### 3.1 Multi-Database Executor
- [ ] Rewrite `lib/selecto/executor.ex` to use adapter pattern
- [ ] Implement query transformation pipeline
- [ ] Add parameter transformation logic
- [ ] Handle result set normalization
- [ ] Implement error normalization across databases
- [ ] Add execution hooks for database-specific optimizations

### 3.2 Transaction Management
- [ ] Create `lib/selecto/transaction.ex` for cross-database transactions
- [ ] Implement savepoint abstraction
- [ ] Add distributed transaction support (2PC where available)
- [ ] Handle isolation level differences
- [ ] Create rollback/commit abstractions

## Phase 4: Built-in PostgreSQL Adapter (Week 4)

### 4.1 PostgreSQL Adapter (Retrofit Existing)
- [ ] Create `lib/selecto/adapters/postgresql.ex` as built-in adapter
- [ ] Implement adapter behavior for PostgreSQL
- [ ] Move existing PostgreSQL-specific code to adapter
- [ ] Ensure zero breaking changes
- [ ] Add version detection for feature support
- [ ] Make it the default adapter when none specified
- [ ] Write comprehensive adapter tests

### 4.2 Adapter Package Templates
- [ ] Create adapter package generator mix task
- [ ] Create adapter template repository
- [ ] Document adapter development guide
- [ ] Create testing framework for adapters
- [ ] Set up CI/CD templates for adapter packages
- [ ] Create adapter certification process

## Phase 5: Type System & Testing (Week 5)

### 5.1 Cross-Database Types
- [ ] Create comprehensive type mapping system
- [ ] Implement type coercion for each database
- [ ] Handle database-specific types (arrays, JSON, XML)
- [ ] Create type validation system
- [ ] Add custom type support
- [ ] Document type compatibility matrix

### 5.2 Data Migration
- [ ] Create data export/import between databases
- [ ] Handle type conversions during migration
- [ ] Implement streaming for large datasets
- [ ] Add data validation during migration
- [ ] Create migration progress tracking

## Phase 6: Documentation & Release (Week 5)

### 6.1 Test Infrastructure
- [ ] Create `test/database/adapter_test.exs`
- [ ] Create `test/database/multi_db_test.exs`
- [ ] Implement database fixture system
- [ ] Create cross-database integration tests
- [ ] Add performance benchmarks per database
- [ ] Create compatibility test matrix

### 6.2 Quality Assurance
- [ ] Add Dialyzer specs for all new modules
- [ ] Ensure 100% backward compatibility
- [ ] Create migration guide from v1 to v2
- [ ] Add deprecation warnings where needed
- [ ] Performance regression testing
- [ ] Security audit for SQL injection

## Configuration & Documentation

### Configuration Updates
- [ ] Update configuration system for multi-database
- [ ] Add database auto-detection from Ecto repos
- [ ] Create connection string parsers
- [ ] Add environment-specific configurations
- [ ] Document all configuration options

### Documentation
- [ ] Write adapter development guide
- [ ] Create database compatibility matrix
- [ ] Document feature availability per database
- [ ] Write migration guide for each database
- [ ] Add troubleshooting guide per database
- [ ] Create performance tuning guide

## Code Organization

### New Directory Structure
```
# Core Selecto Package
lib/selecto/
├── database/
│   ├── adapter.ex           # Behavior definition
│   ├── registry.ex          # Adapter registry
│   ├── dialect.ex           # Base dialect module
│   ├── features.ex          # Feature detection
│   ├── types.ex             # Type system interface
│   ├── query_translator.ex  # Query translation
│   └── adapter_loader.ex    # Load external adapters
├── adapters/
│   └── postgresql.ex        # Built-in PostgreSQL adapter only
└── ... (existing structure)

# Separate Adapter Packages (each in own repo/package)
selecto_db_mysql/
├── lib/
│   └── selecto/
│       └── db/
│           └── mysql.ex     # Main adapter module
├── mix.exs
└── ...

selecto_db_sqlite/
├── lib/
│   └── selecto/
│       └── db/
│           └── sqlite.ex    # Main adapter module
├── mix.exs
└── ...
```

### Core Dependencies (No new database drivers)
```elixir
# mix.exs - selecto core
# No additional database drivers needed
# PostgreSQL support remains built-in via Postgrex
{:postgrex, "~> 0.17"}  # Keep existing
```

### Adapter Package Dependencies
```elixir
# selecto_db_mysql/mix.exs
{:selecto, "~> 1.0"},
{:myxql, "~> 0.6"}

# selecto_db_sqlite/mix.exs
{:selecto, "~> 1.0"},
{:exqlite, "~> 0.13"}

# selecto_db_mssql/mix.exs
{:selecto, "~> 1.0"},
{:tds, "~> 2.3"}

# selecto_db_oracle/mix.exs
{:selecto, "~> 1.0"},
{:jamdb_oracle, "~> 0.5"}
```

## Breaking Changes & Migration

### Potential Breaking Changes
- [ ] None planned - full backward compatibility required

### Deprecations
- [ ] Mark `postgrex_opts` as deprecated (maintain for compatibility)
- [ ] Deprecate direct Postgrex calls in favor of adapter

### Migration Path
- [ ] Existing code continues to work unchanged
- [ ] New features available via opt-in configuration
- [ ] Gradual migration to adapter pattern

## Performance Considerations

### Optimization Tasks
- [ ] Implement query caching per database
- [ ] Add prepared statement support where available
- [ ] Optimize parameter binding for each database
- [ ] Add connection pooling optimization
- [ ] Implement lazy loading for large result sets
- [ ] Add query plan analysis tools

## Error Handling

### Error Standardization
- [ ] Create unified error types across databases
- [ ] Map database-specific errors to Selecto errors
- [ ] Add helpful error messages with solutions
- [ ] Implement retry logic for transient failures
- [ ] Add circuit breaker for connection issues

## Success Criteria

- [ ] All existing PostgreSQL tests pass unchanged
- [ ] MySQL support with 90% feature parity
- [ ] SQLite support with automatic feature emulation
- [ ] SQL Server support with full enterprise features
- [ ] Zero performance regression for PostgreSQL
- [ ] Clean adapter API for future databases