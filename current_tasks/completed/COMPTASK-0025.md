# COMPTASK-0025: CTE Visualization and Management

## Status: Completed
## Priority: MEDIUM
## Effort: 2 days
## Phase: 4.2
## Week: 9-10

## Description
Implement visualization and management tools for Common Table Expressions (CTEs) in complex queries.

## Acceptance Criteria
- [ ] CTE dependency graph
- [ ] Visual CTE builder
- [ ] CTE reuse interface
- [ ] Performance metrics per CTE
- [ ] CTE debugging tools
- [ ] Export CTE definitions
- [ ] CTE documentation

## Technical Requirements
- Graph visualization library
- CTE parsing and analysis
- Dependency tracking
- Performance monitoring
- Debug information collection

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/cte/visualizer.ex` (new)
- `vendor/selecto_components/lib/selecto_components/cte/builder.ex` (new)
- `vendor/selecto_components/lib/selecto_components/cte/analyzer.ex` (new)
- JavaScript for graph rendering
- CSS for visualization styling

## Dependencies
- Selecto CTE functionality
- COMPTASK-0024 (Subselect UI)

## Testing Requirements
- Test CTE visualization
- Test dependency tracking
- Test performance analysis
- Test CTE building
- Test export functionality

## Notes
- Handle recursive CTEs
- Optimize for readability
- Provide optimization suggestions