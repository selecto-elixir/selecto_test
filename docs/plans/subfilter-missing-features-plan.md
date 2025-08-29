# Selecto Subfilter Missing Features Implementation Plan

## Overview
This plan addresses the incomplete features identified in the Phase 2.1 Subfilter System implementation. While the core subfilter architecture is complete and functional, several advanced features mentioned in the original plan are only partially implemented or missing entirely.

## Current Implementation Gap Analysis

### 🚨 **Critical Missing Features**

#### 1. Temporal Subfilters - PARTIALLY IMPLEMENTED
**Status**: Parser support exists, but NO SQL generation or testing

**What's Missing:**
- ❌ SQL generation for temporal conditions in all builders (EXISTS, IN, ANY/ALL, Aggregation)
- ❌ Temporal filter test coverage (0 tests currently)
- ❌ Live data validation for temporal scenarios
- ❌ Integration with PostgreSQL INTERVAL functions

**Current State:**
```elixir
# ✅ Parser can parse these:
selecto |> Selecto.subfilter("film.release_year", {:recent, years: 5})
selecto |> Selecto.subfilter("rental.rental_date", {:within_days, 30})

# ❌ But SQL generation fails - no temporal handling in builders
```

#### 2. Compound Operations (AND/OR) - MISSING
**Status**: Planned but not implemented

**What's Missing:**
- ❌ CompoundSpec structure not implemented in actual code
- ❌ Complex logical operations with proper precedence
- ❌ Nested compound operations
- ❌ SQL generation for compound logic

**Planned Syntax:**
```elixir
# ❌ This syntax is planned but not working:
selecto |> Selecto.subfilter({:and, [
  {"film.rating", "R"},
  {"film.release_year", {">", 2000}}
]})

selecto |> Selecto.subfilter({:or, [
  {"film.rating", "R"},
  {"film.category.name", "Action"}
]})
```

#### 3. Advanced Filter Types - PARTIALLY IMPLEMENTED
**Status**: Parser supports some, SQL generation incomplete

**Missing Filter Types:**
- ❌ Range filters (`{"between", min, max}`) - parsed but no SQL generation
- ❌ Statistical aggregations (percentile, stddev) - not implemented
- ❌ Window function subfilters - not implemented
- ❌ Recursive relationship subfilters - not implemented

### 🔄 **Enhancement Opportunities**

#### 4. Advanced Strategy Options - BASIC IMPLEMENTATION
**Current**: Basic EXISTS, IN, ANY, ALL support
**Missing**: 
- ❌ Cost-based strategy selection
- ❌ Index usage hints
- ❌ Query plan optimization
- ❌ Performance-based auto-strategy switching

#### 5. Error Handling and Validation - BASIC IMPLEMENTATION
**Current**: Basic error reporting
**Missing**:
- ❌ Detailed validation messages for temporal filters
- ❌ Relationship path validation with suggested corrections
- ❌ Performance warnings for expensive operations
- ❌ Query complexity analysis

## Implementation Roadmap

### Phase 2.1.1: Critical Gap Filling (2-3 weeks)

#### Week 1: Temporal Subfilters Implementation
**Priority: CRITICAL**

**Deliverables:**
1. **Temporal SQL Generation**
   ```elixir
   # Add to all SQL builders:
   defp build_filter_condition(%{type: :temporal} = filter_spec) do
     case filter_spec.temporal_type do
       :recent_years ->
         "#{qualified_field} > (CURRENT_DATE - INTERVAL '#{filter_spec.value} years')"
       
       :within_days ->
         "#{qualified_field} > (CURRENT_DATE - INTERVAL '#{filter_spec.value} days')"
       
       :within_hours ->
         "#{qualified_field} > (NOW() - INTERVAL '#{filter_spec.value} hours')"
         
       :since_date ->
         "#{qualified_field} > ?"
     end
   end
   ```

2. **Temporal Parameter Extraction**
   ```elixir
   # Add to parameter extraction:
   defp extract_filter_params(%{type: :temporal} = filter_spec) do
     case filter_spec.temporal_type do
       :since_date -> [filter_spec.value]  # Actual date value
       _ -> []  # INTERVAL values are embedded in SQL
     end
   end
   ```

3. **Temporal Test Coverage**
   - Unit tests for temporal parsing (extend existing 12 tests to 16)
   - SQL generation tests for all temporal types
   - Live data tests with actual date filtering scenarios

#### Week 2: Range Filters and Advanced Types
**Priority: HIGH**

**Deliverables:**
1. **Range Filter SQL Generation**
   ```elixir
   defp build_filter_condition(%{type: :range} = filter_spec) do
     "#{qualified_field} BETWEEN ? AND ?"
   end
   
   defp extract_filter_params(%{type: :range} = filter_spec) do
     [filter_spec.min_value, filter_spec.max_value]
   end
   ```

2. **Enhanced Aggregation Support**
   ```elixir
   # Support for additional aggregation functions:
   defp parse_filter_specification({agg_func, operator, value}) 
     when agg_func in [:sum, :avg, :min, :max, :count, :stddev, :percentile] do
     %{type: :aggregation, agg_function: agg_func, operator: operator, value: value}
   end
   ```

#### Week 3: Basic Compound Operations
**Priority: MEDIUM**

**Deliverables:**
1. **CompoundSpec Implementation**
   ```elixir
   defmodule Selecto.Subfilter.CompoundSpec do
     defstruct [:type, :subfilters, :id]
     
     def new(:and, subfilters), do: %__MODULE__{type: :and, subfilters: subfilters, id: generate_id()}
     def new(:or, subfilters), do: %__MODULE__{type: :or, subfilters: subfilters, id: generate_id()}
   end
   ```

2. **Compound SQL Generation**
   ```elixir
   defp build_compound_where_clause(clauses_map, compound_ops) do
     compound_ops
     |> Enum.map(&build_single_compound/1)
     |> Enum.join(" AND ")
   end
   
   defp build_single_compound({:and, subfilter_ids}) do
     conditions = Enum.map(subfilter_ids, &Map.get(clauses_map, &1).sql)
     "(#{Enum.join(conditions, " AND ")})"
   end
   
   defp build_single_compound({:or, subfilter_ids}) do
     conditions = Enum.map(subfilter_ids, &Map.get(clauses_map, &1).sql)
     "(#{Enum.join(conditions, " OR ")})"
   end
   ```

### Phase 2.1.2: Advanced Features (3-4 weeks)

#### Statistical and Window Function Subfilters
**Priority: LOW-MEDIUM**

**Deliverables:**
1. **Statistical Subfilters**
   ```elixir
   # Support for advanced statistical operations:
   selecto |> Selecto.subfilter("film.rental_rate", {:percentile, 90, ">", 4.99})
   selecto |> Selecto.subfilter("film.length", {:stddev, "<", 30})
   ```

2. **Window Function Integration**
   ```elixir
   # Window function subfilters (requires Window Functions plan):
   selecto |> Selecto.subfilter("film.release_year", {:rank_within, "category.name", "<", 10})
   ```

#### Performance and Optimization Features
**Priority: MEDIUM**

**Deliverables:**
1. **Advanced Strategy Selection**
   ```elixir
   # Cost-based strategy selection:
   selecto = Selecto.configure(domain, postgrex_opts, subfilter_optimizer: :cost_based)
   
   # Index usage hints:
   selecto |> Selecto.subfilter("film.rating", "R", hint: {:use_index, "film_rating_idx"})
   ```

2. **Query Performance Analysis**
   ```elixir
   # Performance monitoring and suggestions:
   %{
     estimated_cost: 150,
     index_usage: [:film_rating_idx],
     optimization_suggestions: [
       "Consider using IN strategy for high selectivity",
       "Index on film.release_year would improve performance"
     ]
   }
   ```

## Testing Strategy

### Unit Test Expansion
**Current**: 30/30 passing
**Target**: 45+ tests

**New Test Categories:**
1. **Temporal Tests** (6 additional tests)
   - Recent years parsing and SQL generation
   - Within days parsing and SQL generation  
   - Since date parsing and SQL generation
   - Edge cases (negative values, zero, large numbers)
   - PostgreSQL INTERVAL validation
   - Timezone handling

2. **Range Filter Tests** (4 additional tests)
   - BETWEEN operator SQL generation
   - Parameter extraction for min/max values
   - Edge cases (min > max, equal values)
   - Type conversion for different numeric types

3. **Compound Operation Tests** (6 additional tests)
   - AND compound parsing and SQL generation
   - OR compound parsing and SQL generation
   - Nested compounds (AND within OR)
   - Mixed strategy compounds
   - Parameter combining for compound operations
   - Precedence handling

### Live Data Test Expansion  
**Current**: 11/11 passing
**Target**: 18+ tests

**New Integration Test Scenarios:**
1. **Temporal Integration** (3 additional tests)
   - Films released in recent years
   - Rentals within specific time periods
   - Date range filtering with real timestamps

2. **Complex Compound Operations** (3 additional tests)
   - Multi-criteria film filtering (rating AND year AND category)
   - Actor filtering with OR conditions across relationships
   - Performance comparison: compound subfilters vs multiple queries

3. **Advanced Filter Types** (1 additional test)
   - Range filtering on numeric fields (rental_rate, length)

## Implementation Priority Matrix

### Critical (Must Complete)
1. **Temporal Subfilters** - Blocking production usage of time-based filtering
2. **Range Filters** - Basic functionality gap that should exist
3. **Test Coverage** - Critical for production reliability

### High Priority (Should Complete)
1. **Basic Compound Operations** - Enables complex multi-criteria filtering
2. **Enhanced Error Messages** - Improves developer experience
3. **Performance Monitoring** - Production operational requirements

### Medium Priority (Nice to Have)
1. **Advanced Strategy Selection** - Optimization improvements
2. **Statistical Subfilters** - Specialized analytics needs
3. **Window Function Integration** - Depends on Window Functions plan completion

### Low Priority (Future Enhancement)
1. **Recursive Relationships** - Specialized tree/hierarchy scenarios
2. **Custom Aggregation Functions** - Advanced analytical requirements

## Success Metrics

### Gap Filling Success (Phase 2.1.1)
- ✅ **Temporal Coverage**: 100% of temporal syntax works end-to-end
- ✅ **Range Coverage**: BETWEEN operations fully functional
- ✅ **Test Expansion**: Unit tests increase from 30 to 40+
- ✅ **Live Data**: Integration tests increase from 11 to 15+
- ✅ **Documentation**: All new features documented with examples

### Advanced Feature Success (Phase 2.1.2)
- ✅ **Compound Operations**: AND/OR subfilters fully functional
- ✅ **Performance**: Query optimization suggestions working
- ✅ **Statistical**: Basic statistical subfilters implemented
- ✅ **Production Ready**: All features have comprehensive test coverage

## Resource Requirements

### Phase 2.1.1 (Gap Filling)
- **Team Size**: 1-2 developers
- **Timeline**: 2-3 weeks
- **Skills Required**: Elixir, PostgreSQL, SQL generation, testing

### Phase 2.1.2 (Advanced Features)
- **Team Size**: 2-3 developers  
- **Timeline**: 3-4 weeks
- **Skills Required**: Advanced SQL, query optimization, statistical functions

## Conclusion

This plan addresses the critical gaps in the current subfilter implementation while providing a roadmap for advanced features. The temporal subfilters are the highest priority since they represent a significant functionality gap that could block production usage.

**Immediate Next Steps:**
1. **Start with temporal SQL generation** - highest impact, most critical
2. **Add comprehensive temporal testing** - ensure reliability
3. **Implement range filters** - complete basic functionality
4. **Plan compound operations** - enable advanced use cases

**Success Definition:**
- All advertised subfilter syntax works end-to-end
- Comprehensive test coverage for production reliability  
- Performance monitoring for operational excellence
- Clear documentation for developer adoption

This plan transforms the current "partially implemented" status into a truly complete and production-ready subfilter system.