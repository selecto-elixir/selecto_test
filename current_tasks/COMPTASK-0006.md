# COMPTASK-0006: Interactive Debug Panel

## Status: Not Started
## Priority: CRITICAL
## Effort: 1 day
## Phase: 1.1
## Week: 1

## Description
Create an interactive debug panel that displays query and parameter information in development mode, with toggles for controlling what information is shown.

## Acceptance Criteria
- [ ] Debug panel shows SQL queries (when configured)
- [ ] Debug panel shows parameters (when configured)
- [ ] Debug panel shows execution timing
- [ ] Debug panel shows row counts
- [ ] Interactive toggles to show/hide sections
- [ ] Copy-to-clipboard for queries
- [ ] Collapsible panel design
- [ ] Respects domain configuration

## Technical Requirements
- Create debug panel component
- Implement toggle controls
- SQL formatting for display
- Parameter formatting/truncation
- Clipboard integration

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/debug/debug_panel.ex` (new)
- `vendor/selecto_components/lib/selecto_components/debug/query_display.ex` (new)
- JavaScript hooks for interactions

## Dependencies
- COMPTASK-0002 (Domain configuration)

## Testing Requirements
- Test panel display/hide
- Test toggle functionality
- Test with various configurations
- Test clipboard functionality
- Test SQL formatting

## Notes
- Should be visually distinct from main UI
- Performance metrics should be accurate
- Consider mobile responsiveness