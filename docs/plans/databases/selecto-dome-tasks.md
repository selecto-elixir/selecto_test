# SelectoDome - Universal Database Support Task List

**Repository:** `vendor/selecto_dome/`  
**Priority:** Medium  
**Estimated Effort:** 2 weeks  
**Dependencies:** Selecto Core database support must be completed first

## Phase 1: Database Abstraction (Week 1)

### 1.1 Core Updates
- [ ] Update `lib/selecto_dome.ex` to handle different database types
- [ ] Modify dome initialization to detect database adapter
- [ ] Add database type to dome metadata
- [ ] Update query analysis for different SQL dialects
- [ ] Implement database-specific query parsing
- [ ] Add adapter pattern for database operations

### 1.2 Transaction Management
- [ ] Create database-agnostic transaction wrapper
- [ ] Handle different transaction isolation levels
  - [ ] PostgreSQL: READ COMMITTED, REPEATABLE READ, SERIALIZABLE
  - [ ] MySQL: READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ, SERIALIZABLE
  - [ ] SQLite: DEFERRED, IMMEDIATE, EXCLUSIVE
  - [ ] SQL Server: Snapshot isolation
- [ ] Implement savepoint support where available
- [ ] Add two-phase commit for supported databases
- [ ] Handle transaction retry logic per database

### 1.3 Query Analysis Updates
- [ ] Update query parser for different SQL dialects
- [ ] Handle different parameter binding styles
  - [ ] PostgreSQL: $1, $2
  - [ ] MySQL: ?
  - [ ] SQL Server: @param1
  - [ ] Oracle: :1
- [ ] Parse database-specific functions
- [ ] Handle different identifier quoting
- [ ] Analyze CTEs and window functions where supported

## Phase 2: Change Tracking (Week 1)

### 2.1 Multi-Database Change Tracking
- [ ] Adapt change detection for different databases
- [ ] Handle different data type conversions
- [ ] Track database-specific column types
- [ ] Implement type coercion per database
- [ ] Handle NULL vs empty string differences
- [ ] Track precision/scale for decimals

### 2.2 Data Validation
- [ ] Implement database-specific validation rules
- [ ] Handle different constraint types
  - [ ] PostgreSQL: CHECK, EXCLUDE
  - [ ] MySQL: Limited CHECK support
  - [ ] SQLite: Limited constraint support
  - [ ] SQL Server: Full constraint support
- [ ] Validate data types per database
- [ ] Check for feature availability
- [ ] Implement custom validation functions

### 2.3 Conflict Resolution
- [ ] Handle different conflict resolution strategies
  - [ ] PostgreSQL: ON CONFLICT
  - [ ] MySQL: ON DUPLICATE KEY
  - [ ] SQLite: ON CONFLICT
  - [ ] SQL Server: MERGE
- [ ] Implement optimistic locking per database
- [ ] Handle concurrent update scenarios
- [ ] Add conflict detection mechanisms

## Phase 3: CRUD Operations (Week 2)

### 3.1 Insert Operations
- [ ] Handle different INSERT syntaxes
- [ ] Support RETURNING clause where available
- [ ] Handle auto-increment differences
  - [ ] PostgreSQL: SERIAL/IDENTITY
  - [ ] MySQL: AUTO_INCREMENT
  - [ ] SQLite: AUTOINCREMENT
  - [ ] SQL Server: IDENTITY
- [ ] Implement batch insert optimizations
- [ ] Handle generated columns

### 3.2 Update Operations
- [ ] Adapt UPDATE syntax per database
- [ ] Handle JOIN in UPDATE (where supported)
- [ ] Implement UPDATE RETURNING where available
- [ ] Handle computed column updates
- [ ] Optimize bulk updates per database

### 3.3 Delete Operations
- [ ] Handle different DELETE syntaxes
- [ ] Support CASCADE options per database
- [ ] Implement soft delete patterns
- [ ] Handle DELETE with JOIN where supported
- [ ] Add deletion validation

### 3.4 Upsert Operations
- [ ] Implement database-specific upsert
  - [ ] PostgreSQL: INSERT ... ON CONFLICT
  - [ ] MySQL: INSERT ... ON DUPLICATE KEY UPDATE
  - [ ] SQLite: INSERT ... ON CONFLICT
  - [ ] SQL Server: MERGE
- [ ] Handle partial index updates
- [ ] Implement conditional upserts
- [ ] Add upsert validation

## Phase 4: Advanced Features (Week 2)

### 4.1 Bulk Operations
- [ ] Optimize bulk inserts per database
  - [ ] PostgreSQL: COPY command
  - [ ] MySQL: LOAD DATA INFILE
  - [ ] SQLite: Batch transactions
  - [ ] SQL Server: BULK INSERT
- [ ] Implement streaming for large datasets
- [ ] Add progress tracking for bulk operations
- [ ] Handle bulk update strategies
- [ ] Implement bulk delete optimizations

### 4.2 Database-Specific Features
- [ ] Support PostgreSQL-specific features
  - [ ] Array operations
  - [ ] JSON/JSONB operations
  - [ ] Full-text search with tsvector
- [ ] Support MySQL-specific features
  - [ ] Full-text search with MATCH AGAINST
  - [ ] Spatial data types
- [ ] Support SQLite-specific features
  - [ ] In-memory databases
  - [ ] Attached databases
- [ ] Support SQL Server-specific features
  - [ ] Temporal tables
  - [ ] XML data type
  - [ ] Hierarchical data

### 4.3 Performance Optimization
- [ ] Add database-specific query hints
- [ ] Implement index awareness
- [ ] Add query plan analysis
- [ ] Optimize for database-specific execution plans
- [ ] Implement caching strategies per database

## Testing

### 5.1 Unit Tests
- [ ] Test dome operations with each database adapter
- [ ] Test transaction management per database
- [ ] Test change tracking across databases
- [ ] Test type conversions
- [ ] Test conflict resolution

### 5.2 Integration Tests
- [ ] Test with real database connections
- [ ] Test cross-database data migration
- [ ] Test concurrent operations
- [ ] Test error scenarios
- [ ] Test performance characteristics

### 5.3 Compatibility Tests
- [ ] Ensure PostgreSQL compatibility unchanged
- [ ] Test feature detection
- [ ] Test fallback mechanisms
- [ ] Test database switching
- [ ] Test mixed database operations

## Error Handling

### 6.1 Database-Specific Errors
- [ ] Map database errors to dome errors
- [ ] Handle constraint violations per database
- [ ] Process deadlock errors
- [ ] Handle connection errors
- [ ] Implement retry strategies

### 6.2 Error Recovery
- [ ] Implement rollback strategies
- [ ] Add partial commit handling
- [ ] Create error recovery mechanisms
- [ ] Log errors appropriately
- [ ] Provide meaningful error messages

## Documentation

### 7.1 API Documentation
- [ ] Document database-specific behavior
- [ ] Create compatibility matrix
- [ ] Document limitations per database
- [ ] Add migration guides
- [ ] Create troubleshooting guide

### 7.2 Examples
- [ ] Create examples for each database
- [ ] Show feature differences
- [ ] Demonstrate fallback strategies
- [ ] Provide performance comparisons
- [ ] Add best practices

## Performance

### 8.1 Benchmarking
- [ ] Benchmark dome operations per database
- [ ] Compare transaction performance
- [ ] Measure bulk operation speed
- [ ] Analyze memory usage
- [ ] Profile critical paths

### 8.2 Optimization
- [ ] Optimize hot paths per database
- [ ] Implement prepared statements
- [ ] Add connection pooling
- [ ] Optimize change detection
- [ ] Reduce memory allocations

## Configuration

### 9.1 Dome Configuration
- [ ] Add database-specific options
- [ ] Configure transaction behavior
- [ ] Set performance parameters
- [ ] Add feature flags
- [ ] Configure error handling

### 9.2 Runtime Configuration
- [ ] Allow runtime database switching
- [ ] Configure pooling parameters
- [ ] Set timeout values
- [ ] Configure retry behavior
- [ ] Add monitoring hooks

## Migration Support

### 10.1 Data Migration
- [ ] Support cross-database migration
- [ ] Handle type conversions
- [ ] Migrate constraints
- [ ] Transfer indexes
- [ ] Preserve relationships

### 10.2 Schema Migration
- [ ] Convert table definitions
- [ ] Migrate column types
- [ ] Transfer constraints
- [ ] Convert indexes
- [ ] Handle database-specific features

## Monitoring

### 11.1 Telemetry
- [ ] Add database type to telemetry
- [ ] Track operation performance
- [ ] Monitor error rates
- [ ] Track feature usage
- [ ] Add custom metrics

### 11.2 Logging
- [ ] Log database operations
- [ ] Track slow queries
- [ ] Log errors with context
- [ ] Add debug logging
- [ ] Implement audit logging

## Success Criteria

- [ ] All existing PostgreSQL functionality preserved
- [ ] Transparent database switching
- [ ] Consistent API across databases
- [ ] Graceful feature degradation
- [ ] No performance regression
- [ ] Comprehensive error handling
- [ ] Full test coverage
- [ ] Complete documentation