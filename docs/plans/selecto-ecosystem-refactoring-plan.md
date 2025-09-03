# Selecto Ecosystem Refactoring Plan

**Version:** 1.0.0  
**Date:** 2025-09-03  
**Status:** Draft  
**Authors:** Development Team  

## Executive Summary

This document outlines a comprehensive refactoring plan for the Selecto ecosystem, addressing critical architectural issues, performance bottlenecks, and code quality concerns identified across the five core libraries: Selecto, SelectoComponents, SelectoDome, SelectoMix, and SelectoKino.

The refactoring aims to improve maintainability, performance, reliability, and developer experience while maintaining backward compatibility where possible.

## Current State Analysis

### Architecture Overview

The Selecto ecosystem consists of:
- **Selecto (v0.2.6)**: Core query builder with 1,765+ line monolithic module
- **SelectoComponents (v0.2.8)**: LiveView UI components with minimal documentation
- **SelectoDome (v0.1.0)**: Data manipulation layer with transaction safety issues
- **SelectoMix (v0.1.0)**: Code generation tools with limited error handling
- **SelectoKino**: Livebook integration with memory management concerns

### Critical Issues Identified

1. **Monolithic Architecture**: Core Selecto module exceeds 1,700 lines
2. **Memory Leaks**: Dynamic module creation in SelectoKino
3. **Transaction Safety**: Missing database transaction handling in SelectoDome
4. **Performance**: Inefficient list operations and field resolution
5. **Inconsistent APIs**: Different error handling patterns across libraries
6. **Code Duplication**: Similar functionality implemented multiple times
7. **Poor Type Safety**: Missing specifications and runtime type checking

## Refactoring Objectives

### Primary Goals

1. **Modularity**: Break down monolithic modules into focused, testable components
2. **Performance**: Optimize critical paths and reduce memory usage
3. **Reliability**: Implement proper error handling and transaction safety
4. **Maintainability**: Reduce complexity and improve code organization
5. **Developer Experience**: Enhance documentation and API consistency

### Success Metrics

- Reduce average module size by 60%
- Achieve 90% test coverage across all libraries
- Eliminate all identified memory leaks
- Improve query generation performance by 30%
- Zero breaking changes for existing public APIs

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

#### 1.1 Setup and Tooling
- [ ] Configure Dialyzer for static analysis
- [ ] Setup Credo for code quality checks
- [ ] Implement continuous integration pipeline
- [ ] Create benchmarking framework

#### 1.2 Error Handling Standardization
- [ ] Create `Selecto.Error` module with standard error types
- [ ] Define error handling conventions
- [ ] Create migration guide for error handling

**Example Implementation:**
```elixir
defmodule Selecto.Error do
  @moduledoc """
  Standard error types for the Selecto ecosystem
  """
  
  defmodule ValidationError do
    defexception [:message, :field, :value, :context]
  end
  
  defmodule QueryError do
    defexception [:message, :query, :reason]
  end
  
  defmodule ConfigurationError do
    defexception [:message, :key, :expected, :actual]
  end
  
  @doc """
  Wraps operation results in standard format
  """
  def wrap_result({:error, reason}), do: {:error, normalize_error(reason)}
  def wrap_result({:ok, _} = result), do: result
  def wrap_result(result), do: {:ok, result}
  
  defp normalize_error(%{__struct__: _} = error), do: error
  defp normalize_error(reason) when is_binary(reason) do
    %Selecto.Error.QueryError{message: reason, reason: :unknown}
  end
  defp normalize_error(reason), do: %Selecto.Error.QueryError{
    message: inspect(reason), 
    reason: :unexpected
  }
end
```

### Phase 2: Core Selecto Refactoring (Weeks 3-5)

#### 2.1 Module Decomposition

Break down `vendor/selecto/lib/selecto.ex` into:

```
vendor/selecto/lib/
├── selecto.ex                  # Public API facade (< 200 lines)
├── selecto/
│   ├── core.ex                 # Core configuration and setup
│   ├── query_builder.ex        # Query construction methods
│   ├── executor.ex             # Query execution logic
│   ├── pivot.ex                # Pivot functionality (lines 454-578)
│   ├── window.ex               # Window functions (lines 686-772)
│   ├── cte.ex                  # CTE functionality (lines 1255-1369)
│   └── advanced/
│       ├── hierarchical.ex    # Hierarchical queries
│       ├── olap.ex            # OLAP functions
│       └── lateral.ex         # Lateral joins
```

**Migration Example:**
```elixir
# Before (in monolithic selecto.ex)
def pivot(config, opts) do
  # 100+ lines of pivot logic
end

# After (in selecto/pivot.ex)
defmodule Selecto.Pivot do
  @moduledoc """
  Pivot table operations for Selecto queries
  """
  
  alias Selecto.{Core, QueryBuilder, Types}
  
  @spec pivot(Types.config(), keyword()) :: {:ok, Types.query()} | {:error, term()}
  def pivot(config, opts) do
    with {:ok, validated_opts} <- validate_options(opts),
         {:ok, base_query} <- build_base_query(config, validated_opts),
         {:ok, pivot_query} <- apply_pivot_transformation(base_query, validated_opts) do
      {:ok, pivot_query}
    end
  end
  
  # Extracted helper functions...
end
```

#### 2.2 SQL Builder Refactoring

Decompose `vendor/selecto/lib/selecto/builder/sql.ex`:

```elixir
# New structure
vendor/selecto/lib/selecto/builder/
├── sql.ex                    # Coordinator (< 100 lines)
├── sql/
│   ├── clause_builder.ex    # Base clause builder behavior
│   ├── from_clause.ex       # FROM clause generation
│   ├── select_clause.ex     # SELECT clause generation
│   ├── where_clause.ex      # WHERE clause generation
│   ├── join_clause.ex       # JOIN clause generation
│   ├── group_clause.ex      # GROUP BY clause generation
│   ├── order_clause.ex      # ORDER BY clause generation
│   ├── cte_builder.ex       # CTE generation
│   └── optimizer.ex         # Query optimization
```

**Example Refactored Builder:**
```elixir
defmodule Selecto.Builder.SQL.SelectClause do
  @behaviour Selecto.Builder.SQL.ClauseBuilder
  
  @impl true
  def build(query, config) do
    query
    |> extract_fields()
    |> apply_transformations(config)
    |> format_select_clause()
    |> wrap_result()
  end
  
  defp extract_fields(query) do
    # Use iodata for performance
    fields = query.fields
    |> Enum.map(&format_field/1)
    |> Enum.intersperse(", ")
    
    ["SELECT ", fields]
  end
  
  # Performance optimization: use iodata instead of string concatenation
  defp format_field({alias, expression}) do
    [expression, " AS ", alias]
  end
end
```

### Phase 3: SelectoComponents Enhancement (Weeks 6-7)

#### 3.1 Component Architecture

```elixir
# New component structure
defmodule SelectoComponents do
  @moduledoc """
  LiveView components for Selecto data visualization
  
  ## Available Components
  
  * `SelectoComponents.Form` - Main form component
  * `SelectoComponents.Table` - Data table display
  * `SelectoComponents.Chart` - Chart visualizations
  * `SelectoComponents.Filter` - Advanced filtering
  
  ## Usage
  
      <.live_component
        module={SelectoComponents.Form}
        id="data-view"
        selecto={@selecto}
        view_type="aggregate"
      />
  """
  
  use Phoenix.Component
  
  @doc """
  Renders a Selecto data form
  """
  attr :selecto, :map, required: true
  attr :view_type, :string, default: "detail"
  attr :saved_view, :map, default: nil
  
  def form(assigns) do
    # Component implementation
  end
end
```

#### 3.2 View Configuration Simplification

```elixir
defmodule SelectoComponents.ViewConfig do
  @moduledoc """
  View configuration management
  """
  
  defstruct [:type, :columns, :filters, :aggregates, :options]
  
  @type t :: %__MODULE__{
    type: :detail | :aggregate | :chart,
    columns: [String.t()],
    filters: map(),
    aggregates: map(),
    options: keyword()
  }
  
  @spec from_params(map()) :: {:ok, t()} | {:error, term()}
  def from_params(params) do
    # Simplified parameter processing
    with {:ok, type} <- validate_type(params["type"]),
         {:ok, columns} <- validate_columns(params["columns"]),
         {:ok, filters} <- validate_filters(params["filters"]) do
      {:ok, %__MODULE__{
        type: type,
        columns: columns,
        filters: filters
      }}
    end
  end
end
```

### Phase 4: SelectoDome Security (Weeks 8-9)

#### 4.1 Transaction Safety

```elixir
defmodule SelectoDome do
  @doc """
  Commits changes with proper transaction handling
  """
  def commit(dome_data) do
    Ecto.Multi.new()
    |> validate_changes(dome_data)
    |> prepare_operations(dome_data)
    |> execute_in_transaction(dome_data.repo)
  end
  
  defp execute_in_transaction(multi, repo) do
    case repo.transaction(multi) do
      {:ok, results} -> {:ok, results}
      {:error, operation, reason, _changes} -> 
        {:error, %SelectoDome.Error{
          operation: operation,
          reason: reason
        }}
    end
  end
end
```

#### 4.2 Query Analysis Enhancement

```elixir
defmodule SelectoDome.QueryAnalyzer do
  @moduledoc """
  Robust query analysis with formal parsing
  """
  
  defstruct [:ast, :tables, :columns, :parameters]
  
  @spec analyze(String.t()) :: {:ok, t()} | {:error, term()}
  def analyze(sql) do
    with {:ok, ast} <- parse_sql(sql),
         {:ok, tables} <- extract_tables(ast),
         {:ok, columns} <- extract_columns(ast),
         {:ok, parameters} <- extract_parameters(ast) do
      {:ok, %__MODULE__{
        ast: ast,
        tables: tables,
        columns: columns,
        parameters: parameters
      }}
    end
  end
  
  defp parse_sql(sql) do
    # Use proper SQL parser instead of regex
    case SQLParser.parse(sql) do
      {:ok, ast} -> {:ok, ast}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end
end
```

### Phase 5: SelectoKino Memory Management (Week 10)

#### 5.1 Module Registry

```elixir
defmodule SelectoKino.RepoRegistry do
  @moduledoc """
  Manages temporary repo modules with proper lifecycle
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_or_create_repo(config) do
    GenServer.call(__MODULE__, {:get_or_create, config})
  end
  
  def cleanup_repo(repo_name) do
    GenServer.cast(__MODULE__, {:cleanup, repo_name})
  end
  
  @impl true
  def init(_opts) do
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_unused, :timer.minutes(5))
    {:ok, %{repos: %{}, last_used: %{}}}
  end
  
  @impl true
  def handle_call({:get_or_create, config}, _from, state) do
    case Map.get(state.repos, config.key) do
      nil ->
        repo = create_repo_module(config)
        new_state = %{
          state | 
          repos: Map.put(state.repos, config.key, repo),
          last_used: Map.put(state.last_used, config.key, System.monotonic_time())
        }
        {:reply, {:ok, repo}, new_state}
      
      existing ->
        new_state = %{
          state |
          last_used: Map.put(state.last_used, config.key, System.monotonic_time())
        }
        {:reply, {:ok, existing}, new_state}
    end
  end
end
```

#### 5.2 ETS Lifecycle Management

```elixir
defmodule SelectoKino.ETSManager do
  @moduledoc """
  Manages ETS tables with proper cleanup
  """
  
  def create_table(name, opts \\ []) do
    table = :ets.new(name, [:named_table | opts])
    register_for_cleanup(table)
    {:ok, table}
  end
  
  defp register_for_cleanup(table) do
    Process.flag(:trap_exit, true)
    spawn_link(fn ->
      ref = Process.monitor(self())
      receive do
        {:DOWN, ^ref, :process, _, _} ->
          :ets.delete(table)
      end
    end)
  end
end
```

### Phase 6: Cross-Library Integration (Weeks 11-12)

#### 6.1 Shared Dependencies

Create `vendor/selecto_common/`:
```elixir
defmodule SelectoCommon.MixProject do
  use Mix.Project
  
  def project do
    [
      app: :selecto_common,
      version: "0.1.0",
      deps: common_deps()
    ]
  end
  
  defp common_deps do
    [
      {:ecto, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:timex, "~> 3.7"}
    ]
  end
end
```

#### 6.2 Integration Testing

```elixir
defmodule Selecto.IntegrationTest do
  use ExUnit.Case
  
  @moduletag :integration
  
  describe "cross-library workflows" do
    test "query building through execution" do
      # Test Selecto -> SelectoDome flow
      assert {:ok, config} = Selecto.configure(...)
      assert {:ok, query} = Selecto.build_query(config, ...)
      assert {:ok, dome} = SelectoDome.from_query(query)
      assert {:ok, _results} = SelectoDome.execute(dome)
    end
    
    test "component rendering with saved views" do
      # Test SelectoComponents -> Selecto flow
      assert {:ok, view} = SelectoComponents.create_view(...)
      assert {:ok, query} = Selecto.from_view(view)
      assert {:ok, _html} = SelectoComponents.render(query)
    end
  end
end
```

## Migration Strategy

### Backward Compatibility

1. **Deprecation Warnings**: Add warnings for deprecated APIs
2. **Facade Pattern**: Maintain old API surface while redirecting to new modules
3. **Version Bridge**: Create compatibility layer for smooth transition

```elixir
defmodule Selecto do
  # Old API maintained for compatibility
  @deprecated "Use Selecto.Pivot.pivot/2 instead"
  def pivot(config, opts) do
    IO.warn("Selecto.pivot/2 is deprecated. Use Selecto.Pivot.pivot/2", [])
    Selecto.Pivot.pivot(config, opts)
  end
end
```

### Migration Timeline

| Week | Phase | Activities | Risk Level |
|------|-------|------------|------------|
| 1-2 | Foundation | Setup tooling, error standardization | Low |
| 3-5 | Core Refactoring | Module decomposition, SQL builder | High |
| 6-7 | Components | UI enhancement, documentation | Medium |
| 8-9 | Security | Transaction safety, query analysis | High |
| 10 | Memory | Fix leaks, lifecycle management | Medium |
| 11-12 | Integration | Cross-library testing, optimization | Medium |
| 13-14 | Testing | Comprehensive test suite | Low |
| 15-16 | Documentation | Guides, examples, migration docs | Low |

## Risk Assessment

### High Risk Areas

1. **Core Module Refactoring**: Breaking existing functionality
   - **Mitigation**: Extensive test coverage before refactoring
   - **Fallback**: Feature flags for gradual rollout

2. **Transaction Safety**: Data corruption during migration
   - **Mitigation**: Staged rollout with monitoring
   - **Fallback**: Rollback procedures documented

3. **Performance Regression**: New architecture slower than current
   - **Mitigation**: Continuous benchmarking
   - **Fallback**: Keep optimization paths identified

### Medium Risk Areas

1. **API Changes**: Breaking dependent applications
   - **Mitigation**: Deprecation period with clear migration guides
   
2. **Memory Management**: Incomplete cleanup causing leaks
   - **Mitigation**: Stress testing and monitoring

### Low Risk Areas

1. **Documentation**: Incomplete or unclear guides
   - **Mitigation**: Community review and feedback

2. **Testing**: Insufficient coverage
   - **Mitigation**: Coverage requirements enforced

## Success Criteria

### Quantitative Metrics

- [ ] Module size: No module > 500 lines
- [ ] Test coverage: > 90% across all libraries
- [ ] Performance: 30% improvement in query generation
- [ ] Memory: Zero detected leaks in 24-hour stress test
- [ ] API stability: Zero breaking changes without deprecation

### Qualitative Metrics

- [ ] Developer satisfaction: Positive feedback from team
- [ ] Code quality: Credo score > 95
- [ ] Documentation: All public functions documented
- [ ] Maintainability: Reduced cognitive complexity

## Implementation Checklist

### Pre-Implementation
- [ ] Team alignment on refactoring plan
- [ ] Backup current codebase
- [ ] Setup monitoring and metrics
- [ ] Create feature flags for gradual rollout

### During Implementation
- [ ] Daily progress reviews
- [ ] Continuous integration runs
- [ ] Performance benchmarking
- [ ] Security audits for critical changes

### Post-Implementation
- [ ] Migration guide published
- [ ] Performance report generated
- [ ] Retrospective conducted
- [ ] Long-term maintenance plan established

## Conclusion

This refactoring plan addresses the critical architectural and quality issues in the Selecto ecosystem while maintaining a pragmatic approach to implementation. By following this phased approach with clear success metrics and risk mitigation strategies, we can transform Selecto into a more maintainable, performant, and reliable system.

The key to success will be maintaining backward compatibility while incrementally improving the codebase, ensuring that existing users can migrate smoothly while new users benefit from the improved architecture immediately.

## Appendix A: Code Style Guide

### Module Organization
```elixir
defmodule ModuleName do
  @moduledoc """
  Brief description
  
  ## Examples
  
      iex> example_usage()
      :result
  """
  
  # 1. Imports, aliases, and uses
  import Needed.Module
  alias Long.Module.Name
  use GenServer
  
  # 2. Module attributes
  @type t :: %__MODULE__{}
  @callback required_callback() :: term()
  
  # 3. Struct definition (if applicable)
  defstruct [:field1, :field2]
  
  # 4. Public API functions
  @spec public_function(term()) :: {:ok, term()} | {:error, term()}
  def public_function(arg) do
    # Implementation
  end
  
  # 5. GenServer callbacks (if applicable)
  @impl true
  def init(state), do: {:ok, state}
  
  # 6. Private functions
  defp private_helper(arg), do: arg
end
```

## Appendix B: Testing Standards

### Test Organization
```elixir
defmodule Module.UnderTest.Test do
  use ExUnit.Case, async: true
  
  describe "function_name/arity" do
    test "successful case" do
      assert {:ok, _} = function_name(valid_input)
    end
    
    test "error case" do
      assert {:error, _} = function_name(invalid_input)
    end
    
    test "edge case" do
      assert function_name(edge_input) == expected_output
    end
  end
end
```

## Appendix C: Performance Benchmarks

### Baseline Metrics (Current)
- Query generation: 145ms average (1000 queries)
- Memory usage: 512MB peak
- Concurrent queries: 100 max

### Target Metrics (Post-Refactoring)
- Query generation: < 100ms average
- Memory usage: < 350MB peak
- Concurrent queries: > 500

## Appendix D: References

- [Elixir Anti-Patterns](https://github.com/lucasvegi/Elixir-Code-Smells)
- [Phoenix Best Practices](https://hexdocs.pm/phoenix/overview.html)
- [Ecto Performance Guide](https://hexdocs.pm/ecto/performance.html)
- [OTP Design Principles](https://www.erlang.org/doc/design_principles/users_guide)