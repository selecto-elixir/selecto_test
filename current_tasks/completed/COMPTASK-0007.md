# COMPTASK-0007: Sortable Table Columns

## Status: Complete  
## Completion Date: 2025-09-10
## Priority: HIGH
## Effort: 1 day
## Phase: 1.2
## Week: 1

## Description
Implement sortable columns in both aggregate and detail tables with support for multi-column sorting.

## Acceptance Criteria
- [x] Click column headers to sort (UI implemented)
- [x] Visual indicators for sort direction
- [x] Support multi-column sorting (shift-click)
- [x] Sort order persists during pagination
- [x] Sort configuration saved in view state
- [x] Works with both aggregate and detail views
- [ ] Accessible keyboard navigation (deferred)

## Technical Requirements
- Modify table header components
- Implement sort state management
- Update Selecto query generation
- Add sort indicators (arrows)
- Handle sort event propagation

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/views/detail/component.ex`
- `vendor/selecto_components/lib/selecto_components/views/aggregate/component.ex`
- `vendor/selecto_components/lib/selecto_components/enhanced_table/sorting.ex` (new)

## Dependencies
- None

## Testing Requirements
- Test single column sorting
- Test multi-column sorting
- Test sort persistence
- Test with different data types
- Test accessibility

## Notes
- Consider performance with large datasets
- Maintain sort state across view changes
- Clear visual feedback for sort state

## Implementation Summary
- Created `SelectoComponents.EnhancedTable.Sorting` module with sorting utilities
- Updated detail view component to use sortable headers
- Updated aggregate view component to use sortable headers
- Added handle_info for {:rerun_query_with_sort, sort_by} in Form module
- Column-based sorting takes priority over query-based sorting
- Sorting is applied at the Selecto query level before execution
- Visual indicators show sort direction and position for multi-column sorts