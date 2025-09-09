# COMPTASK-0004: Production Error Sanitization

## Status: Not Started
## Priority: CRITICAL
## Effort: 0.5 days
## Phase: 1.1
## Week: 1

## Description
Implement error sanitization for production environments to ensure no sensitive information is exposed while still providing helpful error messages.

## Acceptance Criteria
- [ ] All SQL queries are hidden in production
- [ ] All parameters are hidden in production
- [ ] Stack traces are hidden in production
- [ ] Generic user-friendly messages are shown
- [ ] Error types are still identifiable
- [ ] Suggestions remain helpful without exposing details
- [ ] Production mode ignores debug config settings

## Technical Requirements
- Environment detection
- Error message sanitization
- Safe error message templates
- Production-safe suggestions

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/error_handling/error_sanitizer.ex` (new)
- `vendor/selecto_components/lib/selecto_components/error_handling/error_display.ex` (modify)

## Dependencies
- COMPTASK-0001 (Error display foundation)

## Testing Requirements
- Test production mode sanitization
- Test for information leakage
- Test user message clarity
- Test with various error types

## Notes
- Security is paramount
- Messages should still be helpful
- Consider logging full errors server-side