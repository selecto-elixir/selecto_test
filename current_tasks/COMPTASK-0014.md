# COMPTASK-0014: Modal Detail View from Row Click

## Status: Not Started
## Priority: HIGH
## Effort: 2 days
## Phase: 2.1
## Week: 3-4

## Description
Implement modal detail views that open when clicking on a row in aggregate or detail tables, showing full record details with related data.

## Acceptance Criteria
- [ ] Click row to open modal
- [ ] Display all fields for record
- [ ] Show related records in tabs
- [ ] Edit mode toggle
- [ ] Navigation between records
- [ ] Keyboard shortcuts (ESC to close)
- [ ] Responsive modal sizing

## Technical Requirements
- Modal component implementation
- Row click event handling
- Detail data fetching
- Related data loading
- Modal state management

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/modal/detail_modal.ex` (new)
- `vendor/selecto_components/lib/selecto_components/modal/modal_wrapper.ex` (new)
- JavaScript hooks for modal interactions
- CSS for modal styling

## Dependencies
- COMPTASK-0007 (Table foundation)

## Testing Requirements
- Test modal open/close
- Test data loading
- Test navigation between records
- Test keyboard interactions
- Test responsive behavior

## Notes
- Consider lazy loading for related data
- Maintain scroll position in background
- Handle deep linking to modals