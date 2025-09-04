# SelectoMix Comprehensive Improvements Plan

## Executive Summary

SelectoMix requires significant enhancements to support the recent advances in the Selecto ecosystem, particularly around multi-database support (MySQL, SQLite, PostgreSQL), improved join handling, and comprehensive command-line configuration. This plan outlines the necessary improvements to make SelectoMix a robust code generation and management tool for the Selecto ecosystem.

## Current State Analysis

### Existing Capabilities
- Domain generation from Ecto schemas with Igniter support
- Basic LiveView generation
- Saved views integration
- Schema introspection and analysis
- Documentation generation (API docs, guides)
- Parameterized join generation

### Key Limitations
1. **No Database Adapter Awareness** - Generators don't adapt output for different databases
2. **Limited CLI Arguments** - Minimal configuration options for generation behavior
3. **Incomplete Join Comprehension** - Doesn't fully leverage Selecto's advanced join capabilities
4. **No Migration Generation** - Doesn't help with database-specific migration syntax
5. **Static Templates** - Templates don't adapt to database capabilities
6. **No Validation Integration** - Doesn't leverage Selecto's new DomainValidator

## Proposed Improvements

### 1. Database Adapter Support

#### 1.1 Adapter Detection and Configuration
```elixir
# New CLI options
mix selecto.gen.domain Post --adapter mysql
mix selecto.gen.domain Post --adapter sqlite
mix selecto.gen.domain Post --adapter postgres  # default

# Auto-detection from project config
mix selecto.gen.domain Post --auto-detect
```

#### 1.2 Adapter-Specific Code Generation
- **PostgreSQL**: Full feature set, array types, advanced joins
- **MySQL**: JSON arrays instead of native arrays, CTE version checks
- **SQLite**: Text-based UUIDs, limited ALTER TABLE, no RIGHT JOIN

#### 1.3 Implementation Tasks
- [ ] Add adapter detection module (`SelectoMix.AdapterDetector`)
- [ ] Create adapter-specific template variants
- [ ] Add database capability mapping
- [ ] Implement version detection for feature availability
- [ ] Add adapter-specific type mappings

### 2. Comprehensive Command-Line System

#### 2.1 Enhanced CLI Arguments Structure
```bash
# Basic generation with all options
mix selecto.gen.domain MODULE [OPTIONS]

# Core Options
--adapter ADAPTER          # postgres|mysql|sqlite|auto
--output PATH             # Output directory
--force                   # Overwrite existing files
--dry-run                # Preview without creating files
--validate               # Validate domain after generation

# Feature Flags
--associations           # Include associations (default: true)
--joins TYPE            # Join types to generate: all|basic|advanced|none
--custom-columns        # Generate custom column configurations
--filters               # Generate filter configurations
--aggregates            # Generate aggregate configurations
--saved-views           # Generate saved views support
--live                  # Generate LiveView files
--tests                 # Generate test files

# Join Configuration
--join-depth DEPTH      # Max join traversal depth (default: 3)
--join-strategy STRAT   # eager|lazy|optimized (default: optimized)
--parameterized-joins   # Include parameterized join examples
--hierarchical          # Detect and configure hierarchical relationships

# Database-Specific
--mysql-version VERSION    # MySQL version for feature detection
--sqlite-extensions EXTS   # SQLite extensions to assume (json1,fts5)
--postgres-extensions EXTS # PostgreSQL extensions (ltree,cube)

# Schema Selection
--schemas PATTERN         # Schema selection pattern
--exclude PATTERN        # Exclusion pattern
--expand-schemas NAMES   # Schemas to fully expand
--context MODULE        # Context module for organization

# Output Control
--format FORMAT         # compact|expanded|documented
--style STYLE          # phoenix|clean|modular
--namespace NS         # Custom namespace for generated modules
```

#### 2.2 Configuration File Support
```yaml
# .selecto.yml
adapter: postgres
default_options:
  associations: true
  joins: advanced
  validate: true
  
environments:
  development:
    adapter: postgres
  test:
    adapter: sqlite
    sqlite_extensions: [json1, fts5]
  production:
    adapter: mysql
    mysql_version: "8.0"
    
generation:
  output: lib/my_app/selecto_domains
  style: modular
  namespace: MyApp.Selecto
```

#### 2.3 Interactive Mode
```elixir
# Interactive domain generation
mix selecto.gen.domain --interactive

# Prompts:
# 1. Select schemas to generate domains for
# 2. Choose adapter (with auto-detection hint)
# 3. Select features to include
# 4. Configure join relationships
# 5. Preview and confirm
```

### 3. Advanced Join Comprehension

#### 3.1 Join Analysis and Detection
- Analyze foreign key relationships
- Detect many-to-many through junction tables
- Identify hierarchical relationships (self-referential)
- Recognize dimension tables (star schema pattern)
- Detect slowly changing dimensions

#### 3.2 Join Configuration Generation
```elixir
# Generated join configurations based on analysis
joins: %{
  # Basic belongs_to detected from FK
  author: %{
    type: :inner,
    schema: Author,
    on: {:author_id, :id}
  },
  
  # Many-to-many detected via junction table
  tags: %{
    type: :inner,
    schema: Tag,
    through: :post_tags,
    on: [{:id, :post_id}, {:tag_id, :id}]
  },
  
  # Hierarchical self-join detected
  parent: %{
    type: :hierarchical,
    schema: Category,
    strategy: :adjacency_list,
    parent_field: :parent_id,
    child_field: :id
  },
  
  # Dimension join with SCD support
  customer_dimension: %{
    type: :dimension,
    schema: CustomerDim,
    dimension: :type2_scd,
    on: {:customer_id, :customer_key},
    effective_date: :valid_from,
    expiry_date: :valid_to
  }
}
```

#### 3.3 Implementation Tasks
- [ ] Create `SelectoMix.JoinAnalyzer` module
- [ ] Add foreign key detection
- [ ] Implement junction table recognition
- [ ] Add hierarchical relationship detection
- [ ] Create join strategy optimizer
- [ ] Generate join documentation

### 4. Migration Generation Support

#### 4.1 Database-Specific Migrations
```elixir
# Generate migrations adapted to database
mix selecto.gen.migration CreateDomain --adapter mysql

# Generates MySQL-compatible migration
# - Uses JSON instead of arrays
# - Adds appropriate indexes
# - Uses MySQL-specific syntax
```

#### 4.2 Schema Sync Detection
```elixir
# Detect schema drift and generate sync migration
mix selecto.sync.domain Post

# Analyzes:
# - Current database schema
# - Generated domain configuration
# - Produces migration to sync them
```

### 5. Template System Overhaul

#### 5.1 Dynamic Template Selection
```elixir
# Template structure
priv/templates/
  base/
    domain.ex.eex
    queries.ex.eex
  postgres/
    domain.ex.eex     # PostgreSQL-specific features
  mysql/
    domain.ex.eex     # MySQL adaptations
  sqlite/
    domain.ex.eex     # SQLite limitations
```

#### 5.2 Template Variables Enhancement
```elixir
# Enhanced template context
%{
  module: Post,
  adapter: :mysql,
  features: %{
    arrays: false,
    ctes: true,
    window_functions: true,
    full_outer_join: false
  },
  type_mappings: %{
    uuid: :string,
    array: :json
  },
  version: "8.0.32"
}
```

### 6. Validation Integration

#### 6.1 Post-Generation Validation
```elixir
# Automatically validate generated domains
mix selecto.gen.domain Post --validate

# Validates:
# - Domain structure
# - Join references
# - Field references
# - Circular dependencies
```

#### 6.2 Continuous Validation
```elixir
# Add validation task for CI/CD
mix selecto.validate.domains

# Validates all domains in project
# Returns non-zero exit code on failure
```

### 7. Testing Support

#### 7.1 Test Generation
```elixir
# Generate comprehensive test suite
mix selecto.gen.domain Post --tests

# Generates:
# - Domain configuration tests
# - Query builder tests
# - Integration tests
# - Database-specific tests
```

#### 7.2 Test Helpers
```elixir
defmodule PostDomainTest do
  use SelectoMix.DomainCase, adapter: :mysql
  
  test "domain configuration is valid" do
    assert_valid_domain PostDomain.domain()
  end
  
  test "joins are properly configured" do
    assert_join_valid PostDomain.domain(), :author
  end
end
```

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
1. Create adapter detection module
2. Implement comprehensive CLI argument system
3. Add configuration file support
4. Create base template system

### Phase 2: Database Adapters (Weeks 3-4)
1. Implement PostgreSQL adapter support
2. Add MySQL adapter support
3. Add SQLite adapter support
4. Create adapter-specific templates

### Phase 3: Join Intelligence (Weeks 5-6)
1. Build join analyzer
2. Implement relationship detection
3. Create join optimizer
4. Generate join configurations

### Phase 4: Advanced Features (Weeks 7-8)
1. Add migration generation
2. Implement validation integration
3. Create test generation
4. Add interactive mode

### Phase 5: Polish & Documentation (Week 9)
1. Comprehensive testing
2. Documentation updates
3. Example projects
4. Migration guides

## Success Metrics

1. **Adapter Coverage**: Support for all three databases with feature parity
2. **Generation Accuracy**: 95%+ of generated domains work without modification
3. **Developer Efficiency**: 70% reduction in manual domain configuration time
4. **Test Coverage**: 90%+ test coverage for all generators
5. **Documentation**: Complete guides for all features

## Risk Mitigation

### Technical Risks
- **Database Version Variability**: Maintain compatibility matrices
- **Schema Complexity**: Implement progressive enhancement
- **Performance**: Use lazy evaluation and caching

### Process Risks
- **Backward Compatibility**: Maintain legacy command support
- **Migration Path**: Provide upgrade tools and guides
- **User Adoption**: Create comprehensive examples and tutorials

## Dependencies

### External Dependencies
- Igniter for code generation
- Database-specific drivers (Postgrex, MyXQL, Exqlite)
- ExUnit for testing framework

### Internal Dependencies
- Selecto core library updates
- SelectoComponents for UI generation
- SelectoDome for data manipulation

## Conclusion

This comprehensive improvement plan positions SelectoMix as a powerful, database-agnostic code generation tool that significantly reduces the complexity of working with Selecto across different database systems. The enhanced CLI system, intelligent join comprehension, and adapter-aware generation will make SelectoMix an essential tool in the Selecto ecosystem.

## Appendix A: Command Examples

```bash
# Simple domain generation
mix selecto.gen.domain Blog.Post

# MySQL with specific version
mix selecto.gen.domain Blog.Post --adapter mysql --mysql-version 8.0

# SQLite with all features
mix selecto.gen.domain Blog.Post \
  --adapter sqlite \
  --sqlite-extensions json1,fts5 \
  --live \
  --saved-views \
  --tests

# Complex multi-schema generation
mix selecto.gen.domain \
  --all \
  --adapter postgres \
  --exclude "Legacy.*" \
  --expand-schemas "User,Order,Product" \
  --join-depth 4 \
  --parameterized-joins \
  --output lib/my_app/domains \
  --validate

# Interactive mode for beginners
mix selecto.gen.domain --interactive

# Dry run to preview
mix selecto.gen.domain Blog.* --dry-run --adapter mysql

# From configuration file
mix selecto.gen.domain Blog.Post --config .selecto.yml --env production
```

## Appendix B: Configuration Schema

```yaml
# Full .selecto.yml example
version: "1.0"

defaults:
  adapter: postgres
  validate: true
  associations: true
  
adapters:
  postgres:
    extensions: [uuid-ossp, ltree]
    version: "14.0"
  mysql:
    version: "8.0"
    charset: utf8mb4
  sqlite:
    extensions: [json1, fts5]
    journal_mode: wal
    
generation:
  output: lib/my_app/selecto
  style: modular
  format: documented
  namespace: MyApp.Selecto
  
  joins:
    depth: 3
    strategy: optimized
    include_parameterized: true
    
  features:
    custom_columns: true
    filters: true
    aggregates: true
    saved_views: false
    
templates:
  override_path: priv/selecto_templates
  use_custom: true
  
environments:
  development:
    adapter: postgres
    output: lib/my_app/selecto_dev
    
  test:
    adapter: sqlite
    output: lib/my_app/selecto_test
    validate: false
    
  production:
    adapter: mysql
    output: lib/my_app/selecto_prod
    validate: true
    optimize: true
```