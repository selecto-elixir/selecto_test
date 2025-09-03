# SelectoMix - Universal Database Support Task List

**Repository:** `vendor/selecto_mix/`  
**Priority:** Low  
**Estimated Effort:** 1 week  
**Dependencies:** Selecto Core adapter system must be completed first

## Phase 1: Generator Updates (Days 1-3)

### 1.1 Domain Generator Updates
- [ ] Update `lib/mix/tasks/selecto.gen.domain.ex` for database detection
- [ ] Modify domain templates to be database-aware
- [ ] Add database type to generated domain configuration
- [ ] Update column type detection for different databases
- [ ] Handle database-specific naming conventions
- [ ] Add feature detection to generated code

### 1.2 Schema Analyzer Updates
- [ ] Update `lib/selecto_mix/schema_analyzer.ex` for multi-database
- [ ] Add database-specific type mapping
- [ ] Handle different constraint types per database
- [ ] Detect database-specific features in schemas
- [ ] Add index analysis for different databases
- [ ] Handle view and materialized view detection

### 1.3 Template System
- [ ] Create database-specific template variants
- [ ] Add conditional template sections based on database
- [ ] Update code generation for different SQL dialects
- [ ] Handle database-specific imports and dependencies
- [ ] Add feature flags to templates
- [ ] Create fallback templates for limited databases

## Phase 2: Mix Tasks (Days 3-4)

### 2.1 Database Detection Tasks
- [ ] Create `mix selecto.detect_db` task
- [ ] Add database version detection
- [ ] Create feature capability report
- [ ] Generate compatibility warnings
- [ ] Add migration suggestions
- [ ] Create optimization recommendations

### 2.2 Migration Tasks
- [ ] Create `mix selecto.migrate.domain` for cross-database migration
- [ ] Add schema conversion between databases
- [ ] Handle type conversions in migrations
- [ ] Generate migration SQL for different databases
- [ ] Add rollback support per database
- [ ] Create migration validation

### 2.3 Compatibility Tasks
- [ ] Create `mix selecto.compat.check` task
- [ ] Add feature compatibility report
- [ ] Generate workaround suggestions
- [ ] Create compatibility matrix output
- [ ] Add upgrade path recommendations
- [ ] Generate compatibility documentation

## Phase 3: Code Generation (Days 4-5)

### 3.1 Multi-Database Code Generation
- [ ] Update generated queries for database dialect
- [ ] Add database-specific validations
- [ ] Generate appropriate type casts
- [ ] Handle database-specific functions
- [ ] Add conditional code based on features
- [ ] Generate database-specific tests

### 3.2 Test Generation
- [ ] Generate database-specific test cases
- [ ] Add multi-database test templates
- [ ] Create fixture generation per database
- [ ] Generate performance tests
- [ ] Add integration test templates
- [ ] Create compatibility test generation

### 3.3 Documentation Generation
- [ ] Generate database-specific documentation
- [ ] Add capability documentation
- [ ] Create migration guides
- [ ] Generate API documentation per database
- [ ] Add troubleshooting sections
- [ ] Create example generation

## Phase 4: Analysis Tools (Days 5-6)

### 4.1 Schema Analysis
- [ ] Detect Ecto repo database type
- [ ] Analyze schema compatibility
- [ ] Identify database-specific features used
- [ ] Generate optimization suggestions
- [ ] Detect anti-patterns per database
- [ ] Create performance recommendations

### 4.2 Query Analysis
- [ ] Analyze queries for database compatibility
- [ ] Detect non-portable SQL
- [ ] Suggest database-specific optimizations
- [ ] Identify missing indexes
- [ ] Generate query plans per database
- [ ] Add query performance analysis

### 4.3 Migration Analysis
- [ ] Analyze existing migrations
- [ ] Detect database-specific migrations
- [ ] Generate portability report
- [ ] Suggest migration improvements
- [ ] Create rollback analysis
- [ ] Add dependency analysis

## Phase 5: Integration (Days 6-7)

### 5.1 Ecto Integration
- [ ] Detect Ecto adapter type
- [ ] Map Ecto types to Selecto types
- [ ] Handle Ecto migration integration
- [ ] Support Ecto schema introspection
- [ ] Add Ecto query conversion
- [ ] Handle Ecto associations

### 5.2 Project Integration
- [ ] Update project configuration templates
- [ ] Add database dependencies to mix.exs
- [ ] Configure database-specific settings
- [ ] Generate environment configs
- [ ] Add database connection examples
- [ ] Create development setup scripts

## Testing

### 6.1 Generator Tests
- [ ] Test domain generation for each database
- [ ] Test schema analysis per database
- [ ] Test template rendering
- [ ] Test code generation output
- [ ] Test error handling
- [ ] Test edge cases

### 6.2 Task Tests
- [ ] Test detection tasks
- [ ] Test migration tasks
- [ ] Test compatibility checks
- [ ] Test analysis tools
- [ ] Test integration features
- [ ] Test documentation generation

### 6.3 Integration Tests
- [ ] Test with real database connections
- [ ] Test multi-database projects
- [ ] Test migration between databases
- [ ] Test generated code execution
- [ ] Test compatibility warnings
- [ ] Test error scenarios

## Configuration

### 7.1 Generator Configuration
- [ ] Add database options to generators
- [ ] Configure type mappings
- [ ] Set naming conventions
- [ ] Add feature flags
- [ ] Configure template paths
- [ ] Add custom generators

### 7.2 Task Configuration
- [ ] Configure database connections
- [ ] Set analysis parameters
- [ ] Configure output formats
- [ ] Add verbosity levels
- [ ] Set timeout values
- [ ] Configure parallel execution

## Documentation

### 8.1 Usage Documentation
- [ ] Document generator changes
- [ ] Create database-specific guides
- [ ] Document new mix tasks
- [ ] Add troubleshooting guide
- [ ] Create migration documentation
- [ ] Add best practices

### 8.2 API Documentation
- [ ] Document analyzer API changes
- [ ] Add template API documentation
- [ ] Document generator callbacks
- [ ] Create plugin documentation
- [ ] Add extension guide
- [ ] Document configuration API

## Error Handling

### 9.1 Database-Specific Errors
- [ ] Handle connection errors
- [ ] Process schema errors
- [ ] Handle generation failures
- [ ] Manage analysis errors
- [ ] Process migration errors
- [ ] Handle compatibility issues

### 9.2 User Feedback
- [ ] Improve error messages
- [ ] Add helpful suggestions
- [ ] Include documentation links
- [ ] Provide examples in errors
- [ ] Add recovery instructions
- [ ] Include debugging tips

## Performance

### 10.1 Generation Performance
- [ ] Optimize template rendering
- [ ] Cache analysis results
- [ ] Parallelize generation
- [ ] Optimize file I/O
- [ ] Reduce memory usage
- [ ] Add progress indicators

### 10.2 Analysis Performance
- [ ] Optimize schema introspection
- [ ] Cache database metadata
- [ ] Parallelize analysis
- [ ] Optimize query analysis
- [ ] Add incremental analysis
- [ ] Implement lazy loading

## Success Criteria

- [ ] All generators work with PostgreSQL unchanged
- [ ] Support for MySQL, SQLite, SQL Server, Oracle
- [ ] Automatic database detection from Ecto repos
- [ ] Clear warnings for unsupported features
- [ ] Helpful migration and compatibility tools
- [ ] Comprehensive test coverage
- [ ] Complete documentation
- [ ] No performance regression