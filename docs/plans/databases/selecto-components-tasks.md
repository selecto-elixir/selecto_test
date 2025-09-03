# SelectoComponents - Universal Database Support Task List

**Repository:** `vendor/selecto_components/`  
**Priority:** Medium  
**Estimated Effort:** 2-3 weeks  
**Dependencies:** Selecto Core database support must be completed first

## Phase 1: Database Compatibility Layer (Week 1)

### 1.1 Component Adapter Awareness
- [ ] Update `lib/selecto_components/state.ex` to handle adapter type
- [ ] Modify `lib/selecto_components/form.ex` to detect adapter capabilities
- [ ] Update `lib/selecto_components/router.ex` for adapter-specific routing
- [ ] Add adapter information to component assigns
- [ ] Create adapter feature detection helpers
- [ ] Implement fallback UI for unsupported features

### 1.2 View Components Updates
- [ ] Update `lib/selecto_components/views/aggregate/component.ex`
  - [ ] Handle databases without ROLLUP support
  - [ ] Adapt aggregation functions per database
  - [ ] Implement fallback aggregation strategies
- [ ] Update `lib/selecto_components/views/detail/component.ex`
  - [ ] Handle different pagination syntaxes
  - [ ] Adapt to different NULL handling
- [ ] Update `lib/selecto_components/views/graph/component.ex`
  - [ ] Handle time-series differences
  - [ ] Adapt date/time functions per database

### 1.3 Filter Components
- [ ] Update `lib/selecto_components/filter.ex` for database-specific operators
- [ ] Handle different date/time filter formats
- [ ] Adapt full-text search UI per database
  - [ ] PostgreSQL: tsvector/tsquery
  - [ ] MySQL: MATCH AGAINST
  - [ ] SQLite: FTS5
  - [ ] SQL Server: CONTAINS
- [ ] Handle different comparison operators
- [ ] Add database-specific filter validations

## Phase 2: UI Adaptations (Week 2)

### 2.1 Feature Toggle System
- [ ] Create `lib/selecto_components/database/features.ex`
- [ ] Implement UI feature flags based on database
- [ ] Add capability detection functions
- [ ] Create fallback UI components
- [ ] Implement progressive enhancement
- [ ] Add feature availability indicators

### 2.2 Type-Specific Components
- [ ] Handle JSON field display differently per database
- [ ] Adapt array field handling
  - [ ] PostgreSQL: Native arrays
  - [ ] MySQL: JSON arrays
  - [ ] SQLite: Text serialization
  - [ ] SQL Server: JSON arrays
- [ ] Handle boolean display (true/false vs 1/0)
- [ ] Adapt decimal precision display
- [ ] Handle UUID display differences

### 2.3 Query Builder UI
- [ ] Update query builder for database-specific features
- [ ] Show/hide options based on database capabilities
- [ ] Add database-specific query hints
- [ ] Implement query validation per database
- [ ] Add query preview with dialect-specific SQL
- [ ] Handle different join types availability

## Phase 3: Performance Optimizations (Week 3)

### 3.1 Database-Specific Optimizations
- [ ] Implement database-specific pagination strategies
  - [ ] PostgreSQL: LIMIT/OFFSET with cursors
  - [ ] MySQL: Keyset pagination
  - [ ] SQLite: Simple LIMIT/OFFSET
  - [ ] SQL Server: OFFSET FETCH
- [ ] Add database-specific caching strategies
- [ ] Optimize live updates per database
- [ ] Implement lazy loading based on database

### 3.2 LiveView Optimizations
- [ ] Optimize assigns updates for different databases
- [ ] Implement database-specific debouncing
- [ ] Add connection pooling awareness
- [ ] Handle database timeout differences
- [ ] Optimize real-time features per database

## Component-Specific Tasks

### SelectoComponents.Form
- [ ] Add database indicator to form header
- [ ] Show feature availability warnings
- [ ] Adapt form fields to database types
- [ ] Handle different validation rules
- [ ] Add database-specific help text

### SelectoComponents.Table
- [ ] Handle different sorting capabilities
- [ ] Adapt column formatting per database
- [ ] Handle NULL display differences
- [ ] Implement virtual scrolling per database
- [ ] Add export formats per database

### SelectoComponents.Chart
- [ ] Adapt chart data queries per database
- [ ] Handle different aggregation functions
- [ ] Implement time-series adaptations
- [ ] Handle different date grouping
- [ ] Add database-specific chart types

### SelectoComponents.Export
- [ ] Adapt export queries per database
- [ ] Handle different data types in exports
- [ ] Implement streaming exports where supported
- [ ] Add database-specific export formats
- [ ] Handle large dataset exports per database

## JavaScript/Hook Updates

### 3.1 Colocated Hooks
- [ ] Update hooks for database-specific behaviors
- [ ] Add database type to hook params
- [ ] Implement feature detection in JavaScript
- [ ] Handle different date/time formats
- [ ] Adapt validation rules per database

### 3.2 Alpine.js Components
- [ ] Update Alpine components for database awareness
- [ ] Add database-specific interactions
- [ ] Handle different data formats
- [ ] Implement progressive enhancement
- [ ] Add fallback behaviors

## Testing

### 4.1 Multi-Database Testing
- [ ] Create test fixtures for each database
- [ ] Test component rendering with different databases
- [ ] Test feature fallbacks
- [ ] Test performance with different databases
- [ ] Test error handling per database

### 4.2 Integration Tests
- [ ] Test with Selecto core adapters
- [ ] Test real database connections
- [ ] Test feature detection
- [ ] Test UI adaptations
- [ ] Test export/import functionality

## Documentation

### 5.1 Component Documentation
- [ ] Document database-specific features
- [ ] Create compatibility matrix for components
- [ ] Document fallback behaviors
- [ ] Add troubleshooting per database
- [ ] Create migration guides

### 5.2 Developer Documentation
- [ ] Document how to extend for new databases
- [ ] Create component adapter guide
- [ ] Document feature detection API
- [ ] Add performance tuning guide
- [ ] Create best practices guide

## Configuration

### 6.1 Component Configuration
- [ ] Add database-specific component options
- [ ] Create default configs per database
- [ ] Add feature override options
- [ ] Implement custom fallback configuration
- [ ] Add performance tuning options

### 6.2 Styling Configuration
- [ ] Add database-specific CSS classes
- [ ] Create theme variants per database
- [ ] Add feature availability indicators
- [ ] Implement responsive designs for limitations
- [ ] Add accessibility improvements

## LiveView Specific

### 7.1 Socket Updates
- [ ] Add database info to socket assigns
- [ ] Handle database changes without reload
- [ ] Implement connection switching
- [ ] Add database status indicators
- [ ] Handle connection failures gracefully

### 7.2 PubSub Integration
- [ ] Adapt PubSub for different databases
- [ ] Handle real-time updates per database
- [ ] Implement fallback for non-real-time databases
- [ ] Add database-specific channels
- [ ] Handle cross-database notifications

## Migration Support

### 8.1 Backward Compatibility
- [ ] Ensure existing PostgreSQL components work unchanged
- [ ] Add deprecation notices where needed
- [ ] Provide migration helpers
- [ ] Document breaking changes (if any)
- [ ] Create compatibility shims

### 8.2 Progressive Enhancement
- [ ] Start with basic functionality
- [ ] Add advanced features progressively
- [ ] Detect and enable features dynamically
- [ ] Provide graceful degradation
- [ ] Implement feature flags

## Performance Metrics

### 9.1 Monitoring
- [ ] Add database type to telemetry
- [ ] Track feature usage per database
- [ ] Monitor performance per database
- [ ] Track error rates per database
- [ ] Add custom metrics per database

### 9.2 Optimization
- [ ] Profile component performance per database
- [ ] Optimize render cycles
- [ ] Reduce database queries
- [ ] Implement caching strategies
- [ ] Add lazy loading where appropriate

## Error Handling

### 10.1 Database-Specific Errors
- [ ] Handle connection errors per database
- [ ] Provide helpful error messages
- [ ] Implement retry strategies
- [ ] Add fallback UI for errors
- [ ] Log errors appropriately

### 10.2 User Feedback
- [ ] Show database limitations clearly
- [ ] Provide alternative actions
- [ ] Explain why features are unavailable
- [ ] Suggest workarounds
- [ ] Add help documentation links

## Success Criteria

- [ ] All existing components work with PostgreSQL unchanged
- [ ] Components adapt automatically to database capabilities
- [ ] Graceful degradation for missing features
- [ ] No performance regression for PostgreSQL
- [ ] Clear UI indicators for database limitations
- [ ] Comprehensive test coverage for all databases