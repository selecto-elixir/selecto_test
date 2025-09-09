# COMPTASK-0002: Domain-Configurable Debug Information Display

## Status: Not Started
## Priority: CRITICAL
## Effort: 1 day
## Phase: 1.1
## Week: 1

## Description
Implement domain-level configuration for controlling debug information display, allowing developers to configure what debug information is shown per domain.

## Acceptance Criteria
- [ ] Domains can define `debug_config/0` function
- [ ] Config controls query display (show/hide)
- [ ] Config controls parameter display (show/hide)
- [ ] Config controls timing information display
- [ ] Config supports per-view-type settings
- [ ] Config supports SQL formatting options
- [ ] Config reader handles missing configurations gracefully

## Technical Requirements
- Define debug configuration schema
- Create config reader module
- Implement config inheritance/defaults
- Support runtime config overrides

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/debug/config_reader.ex` (new)
- Domain files to add `debug_config/0` function
- Documentation for configuration options

## Dependencies
- None

## Testing Requirements
- Test config reading from domains
- Test default config fallback
- Test per-view-type configurations
- Test config override functionality

## Notes
- Must maintain backward compatibility
- Sensitive domains should be able to disable all debug info
- Consider performance impact of config checks