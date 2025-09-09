# COMPTASK-0012: Advanced Filter Types

## Status: Not Started
## Priority: HIGH
## Effort: 2 days
## Phase: 1.3
## Week: 2-3

## Description
Implement advanced filter types including date ranges, numeric ranges, multi-select, and custom filter expressions.

## Acceptance Criteria
- [ ] Date range picker with presets
- [ ] Numeric range sliders
- [ ] Multi-select dropdown for categorical data
- [ ] Custom expression builder
- [ ] Filter type auto-detection based on data type
- [ ] Visual indicators for active filters
- [ ] Filter preview before applying

## Technical Requirements
- Component for each filter type
- Type detection logic
- Expression parsing and validation
- Date/time handling
- Range validation

## Files to Create/Modify
- `vendor/selecto_components/lib/selecto_components/filter/date_range_filter.ex` (new)
- `vendor/selecto_components/lib/selecto_components/filter/numeric_range_filter.ex` (new)
- `vendor/selecto_components/lib/selecto_components/filter/multi_select_filter.ex` (new)
- `vendor/selecto_components/lib/selecto_components/filter/expression_builder.ex` (new)
- JavaScript for date pickers and sliders

## Dependencies
- COMPTASK-0011 (Dynamic filter addition)

## Testing Requirements
- Test each filter type
- Test type detection
- Test expression parsing
- Test edge cases (invalid dates, ranges)
- Test filter combinations

## Notes
- Consider localization for date formats
- Provide sensible defaults
- Handle timezone considerations