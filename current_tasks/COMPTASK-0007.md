# COMPTASK-0007: Sortable Table Columns

## Status: Not Started
## Priority: HIGH
## Effort: 1 day
## Phase: 1.2
## Week: 1

## Description
Implement sortable columns in both aggregate and detail tables with support for multi-column sorting.

## Acceptance Criteria
- [ ] Click column headers to sort
- [ ] Visual indicators for sort direction
- [ ] Support multi-column sorting (shift-click)
- [ ] Sort order persists during pagination
- [ ] Sort configuration saved in view state
- [ ] Works with both aggregate and detail views
- [ ] Accessible keyboard navigation

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