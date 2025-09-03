# Selecto Implementation Plans

## Current Situation

After thorough analysis, we discovered that **most advanced features ARE already implemented** in Selecto. The 184 test failures are due to:

1. **Incorrect API usage in tests** - Tests use non-existent function names
2. **Wrong syntax in documentation** - Documentation shows aspirational API that differs from actual implementation
3. **Missing domain configurations** - Test helpers don't set up joins properly

Only **CASE expressions** are genuinely not implemented.

## Plans Overview

### 📊 [Feature Analysis](./feature-analysis.md)
Complete analysis of what's implemented vs. what's documented:
- ✅ CTEs (with_cte, with_recursive_cte)
- ✅ Window Functions (window_function)
- ✅ LATERAL Joins (lateral_join)
- ✅ Set Operations (union, intersect, except)
- ✅ Subselects (subselect)
- ⚠️ Array Operations (partial - builder exists, needs API wrapper)
- ⚠️ JSON Operations (partial - builder exists, needs API wrapper)
- ❌ CASE Expressions (not implemented)

### 🔧 [Actual Implementation Needs](./actual-implementation-needs.md)
What really needs to be done:
1. **Fix test files** (1-2 days) - Update to use correct API
2. **Implement CASE expressions** (2-3 days) - Only missing feature
3. **Add convenience wrappers** (1 day) - Better ergonomics
4. **Fix domain configurations** (1 day) - Proper test setup

**Total: 5-7 days** (much less than originally estimated 29-39 days!)

### 📚 [Fix Documentation Examples](./fix-documentation-examples.md)
How to update all documentation to show correct API usage:
- Fix examples in all 9 advanced-features files
- Add complete domain setup examples
- Mark unimplemented features clearly
- Include SQL output for verification

### 🎯 [CASE Expressions Implementation](./01-case-expressions-plan.md)
Detailed plan for the only missing feature:
- API design for simple and searched CASE
- Implementation steps
- Integration with SQL builder
- Testing strategy

## Quick Reference: Correct API Usage

### ✅ What Works Today

```elixir
# CTEs
selecto |> Selecto.with_cte("name", fn base -> ... end)

# Window Functions  
selecto |> Selecto.window_function(:row_number, [], options)

# LATERAL Joins
selecto |> Selecto.lateral_join(:left, fn base -> ... end, "alias")

# Set Operations
Selecto.union(query1, query2)

# Subselects
selecto |> Selecto.subselect([config_map])
```

### ❌ What Doesn't Work (But Tests Try To Use)

```elixir
# These functions don't exist:
Selecto.array_select()  # Use select() with array operations
Selecto.array_filter()  # Use filter() with array operations
Selecto.case_select()   # Not implemented yet
Selecto.json_select()   # Use select() with JSON operations
```

## Priority Actions

### Immediate (This Week)
1. **Fix 5-10 test files** as proof of concept
2. **Update their corresponding documentation**
3. **Verify features actually work**

### Short Term (Next Week)
1. **Implement CASE expressions**
2. **Fix all remaining test files**
3. **Update all documentation**

### Medium Term (Following Week)
1. **Add convenience wrappers** for better ergonomics
2. **Create working examples directory**
3. **Add migration guide from old to new syntax**

## Success Metrics

- [ ] All 184 tests pass
- [ ] Documentation matches actual API
- [ ] CASE expressions implemented
- [ ] No breaking changes to existing code
- [ ] Examples run without errors

## Key Insight

**We don't need to implement 10+ features - they already exist!**  
We just need to:
1. Fix the tests to use the right API
2. Update the docs to show correct usage
3. Implement only CASE expressions
4. Add some convenience wrappers

This changes the timeline from **6+ weeks to 1-2 weeks**.