# COMPTASK-0024: Subselect UI Components

## Status: Not Started
## Priority: HIGH
## Effort: 3 days
## Phase: 4.2
## Week: 9

## Description
Create UI components for building and managing subselects/subqueries within the Selecto interface.

## Acceptance Criteria
- [ ] Visual subquery builder
- [ ] Nested query visualization
- [ ] Drag-and-drop query composition
- [ ] Subquery preview
- [ ] Performance indicators
- [ ] Query optimization hints
- [ ] Save subquery templates

## Technical Requirements
- Subquery builder components
- Query visualization
- Drag-and-drop framework
- Query validation
- Performance analysis

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/subselect/builder.ex` (new)
- `vendor/selecto_components/lib/selecto_components/subselect/visualizer.ex` (new)
- `vendor/selecto_components/lib/selecto_components/subselect/optimizer.ex` (new)
- JavaScript for drag-and-drop
- CSS for query visualization

## Dependencies
- Selecto subselect functionality
- COMPTASK-0003 (Filter management)

## Testing Requirements
- Test subquery building
- Test query composition
- Test visualization
- Test performance analysis
- Test template management

## Notes
- Focus on usability
- Provide query hints
- Consider query complexity limits