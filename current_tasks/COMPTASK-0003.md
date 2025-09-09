# COMPTASK-0003: Enhanced Dev Environment Error Details

## Status: Not Started
## Priority: CRITICAL
## Effort: 1 day
## Phase: 1.1
## Week: 1

## Description
Enhance error display in development environments to show comprehensive debugging information based on domain configuration settings.

## Acceptance Criteria
- [ ] Show full SQL queries when configured
- [ ] Show query parameters when configured
- [ ] Show stack traces for all error types
- [ ] Show component state at time of error
- [ ] Show execution timing information
- [ ] Implement copy-to-clipboard for error details
- [ ] Format SQL for readability

## Technical Requirements
- SQL formatting implementation
- Parameter truncation support
- Stack trace formatting
- Component state capture
- Clipboard API integration

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/error_handling/error_display.ex` (enhance)
- `vendor/selecto_components/lib/selecto_components/debug/query_display.ex` (new)
- JavaScript hooks for clipboard functionality

## Dependencies
- COMPTASK-0001 (Error display foundation)
- COMPTASK-0002 (Domain configuration)

## Testing Requirements
- Test SQL formatting
- Test parameter truncation
- Test clipboard functionality
- Test with various error scenarios

## Notes
- Only active in development environment
- Must respect domain configuration settings
- Consider performance of detail gathering