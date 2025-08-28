# Select Filter Options Implementation Plan

## Overview

This plan outlines the implementation of select-based filtering with valid options across the Selecto ecosystem. The goal is to allow users to filter with select elements showing valid options, detect these situations from DB schema in SelectoMix, and enforce options in SelectoDome.

## Current State Analysis

### Existing Filter Mechanisms
- **SelectoComponents**: Has filters for basic types (string, integer, boolean, dates)
- **Ecto.Enum Support**: Already exists with `{:parameterized, Ecto.Enum, typemap}` using checkbox interface
- **Custom Component Filters**: Supported via `:component` type in domains
- **Example**: `Film.rating` uses `Ecto.Enum` with values ["G", "PG", "PG-13", "R", "NC-17"]

### Domain Configuration
- Domains define `custom_columns` and `filters` with apply functions
- Association structures exist for joins and relationships
- Custom filter components already demonstrated (e.g., `actor_ratings` filter)

### SelectoDome
- Provides validation and constraint checking for data manipulation
- Has change tracking and validation infrastructure

## Implementation Plan

### Phase 1: Core Infrastructure

#### 1. Enhanced Domain Configuration Schema

Add new configuration options to Selecto domains for option providers:

```elixir
# In domain configuration
custom_columns: %{
  "status" => %{
    name: "Status",
    type: :select_options,
    option_provider: %{
      type: :static,  # or :domain, :query, :enum
      values: ["active", "inactive", "pending"]
    }
  },
  "category_id" => %{
    name: "Category", 
    type: :select_options,
    option_provider: %{
      type: :domain,
      domain: :categories_domain,
      value_field: :category_id,
      display_field: :name,
      # Optional: additional filtering
      filters: [{"active", true}]
    }
  },
  "rating" => %{
    name: "MPAA Rating",
    type: :select_options,
    option_provider: %{
      type: :enum,
      schema: SelectoTest.Store.Film,
      field: :rating
    }
  }
}
```

#### 2. SelectoMix Schema Detection

Enhance SelectoMix to automatically detect enum and reference fields:

```elixir
# Detection patterns:
# - Ecto.Enum fields -> :static or :enum options
# - belongs_to associations -> :domain options  
# - foreign key fields -> :domain options
# - Custom enum types -> :static options

# Example generated config:
def detect_select_options(schema_module) do
  schema_module.__schema__(:fields)
  |> Enum.map(&analyze_field(schema_module, &1))
  |> Enum.filter(&is_select_candidate/1)
end
```

#### 3. Filter Type System Extension

Extend existing filter type system with `:select_options` type that integrates with current filter processing.

### Phase 2: UI Components

#### 4. SelectoComponents Filter Forms

Add new filter form for select options in `SelectoComponents.Components.FilterForms`:

```elixir
def render_form(%{type: :select_options} = assigns) do
  # Multi-select dropdown with:
  # - Live search capability
  # - Support for static lists, domain queries
  # - Lazy loading for large option sets
  # - Clear visual feedback
end
```

#### 5. Option Loading Infrastructure

Create efficient option loading system:

```elixir
defmodule SelectoComponents.OptionLoader do
  # Load options from various providers
  # Cache frequently accessed options
  # Handle large option sets with pagination/search
end
```

#### 6. Filter Processing Integration

Integrate with existing filter processing in `SelectoComponents.Helpers.Filters`:

```elixir
# Add case for :select_options type
# Validate selections against option providers
# Generate appropriate Selecto filter clauses
```

### Phase 3: Integration & Validation

#### 7. SelectoDome Validation Enhancement

Enhance SelectoDome validation to enforce option constraints:

```elixir
defmodule SelectoDome.OptionValidator do
  # Validate inserts/updates against option providers
  # Ensure foreign key integrity for domain-based options
  # Check enum constraints for enum-based options
end
```

#### 8. SelectoKino Integration

Add notebook-friendly select interfaces:

```elixir
defmodule SelectoKino.SelectOptions do
  # Kino.Input.select/2 integration
  # Dynamic option loading from domains
  # Preview of filter effects
  # Interactive option exploration
end
```

#### 9. Performance Optimizations

- **Caching**: Cache option lists with configurable TTL
- **Lazy Loading**: Load options on-demand for large datasets
- **Search**: Implement efficient search across option sets
- **Batching**: Batch option requests for multiple filters

## Detailed Implementation Steps

### Step 1: Domain Configuration Schema (Selecto)

**File**: `vendor/selecto/lib/selecto/schema/column.ex`

Add support for `:select_options` type and option providers:

```elixir
@type option_provider :: 
  %{type: :static, values: [term()]} |
  %{type: :domain, domain: atom(), value_field: atom(), display_field: atom(), filters: [term()]} |
  %{type: :enum, schema: module(), field: atom()} |
  %{type: :query, query: String.t(), params: [term()]}
```

### Step 2: SelectoMix Detection (SelectoMix)

**File**: `vendor/selecto_mix/lib/mix/selecto/schema_analyzer.ex`

```elixir
defmodule Mix.Selecto.SchemaAnalyzer do
  def detect_select_options(schema_module) do
    # Analyze schema for enum fields, associations, etc.
    # Generate appropriate option provider configurations
  end
end
```

### Step 3: Filter Forms (SelectoComponents)

**File**: `vendor/selecto_components/lib/selecto_components/components/filter_forms.ex`

Add new render_form clause for `:select_options`:

```elixir
def render_form(%{type: :select_options} = assigns) do
  options = load_options(assigns.def.option_provider, assigns)
  
  ~H"""
  <div>
    <%= @def.name %>
    <.sc_multi_select 
      name={"filters[#{@uuid}][value][]"}
      options={options}
      selected={@valmap["value"] || []}
      searchable={length(options) > 10}
    />
  </div>
  """
end
```

### Step 4: SelectoDome Validation (SelectoDome)

**File**: `vendor/selecto_dome/lib/selecto_dome/option_validator.ex`

```elixir
defmodule SelectoDome.OptionValidator do
  def validate_against_options(value, option_provider) do
    # Validate value against the option provider
    # Return {:ok, value} or {:error, reason}
  end
end
```

### Step 5: SelectoKino Integration (SelectoKino)

**File**: `vendor/selecto_kino/lib/selecto_kino/select_options.ex`

```elixir
defmodule SelectoKino.SelectOptions do
  def filter_input(domain, field) do
    # Create Kino.Input.select with domain options
    # Handle option loading and filtering
  end
end
```

## Key Design Decisions

### Backward Compatibility
- Existing Ecto.Enum support remains unchanged
- Current filter system continues to work
- New `:select_options` type is additive

### Flexible Providers
- **Static**: Hardcoded lists for simple cases
- **Domain**: Query other Selecto domains for options
- **Enum**: Auto-detect from Ecto.Enum schemas
- **Query**: Custom SQL for complex option logic

### Performance Considerations
- Lazy loading for large option sets
- Caching with configurable TTL
- Search/filter capabilities for UX
- Efficient option loading strategies

### Validation Strategy
- Two-tier validation (UI + database)
- SelectoComponents validates on form submission
- SelectoDome validates on data manipulation
- Consistent error messaging across layers

### User Experience
- Search capability for large option lists
- Multi-select with clear visual feedback
- Loading states for async option loading
- Consistent interface across all components

## Example Usage

### Static Options
```elixir
"priority" => %{
  name: "Priority",
  type: :select_options,
  option_provider: %{
    type: :static,
    values: ["low", "medium", "high", "critical"]
  }
}
```

### Domain-Based Options
```elixir
"category_id" => %{
  name: "Category",
  type: :select_options,
  option_provider: %{
    type: :domain,
    domain: :categories_domain,
    value_field: :category_id,
    display_field: :name,
    filters: [{"active", true}]
  }
}
```

### Enum-Based Options
```elixir
"rating" => %{
  name: "MPAA Rating",
  type: :select_options,
  option_provider: %{
    type: :enum,
    schema: SelectoTest.Store.Film,
    field: :rating
  }
}
```

## Testing Strategy

### Unit Tests
- Option provider loading
- Filter form rendering
- Validation logic
- Schema detection

### Integration Tests
- End-to-end filter workflows
- SelectoDome validation
- Performance with large option sets
- Cross-component communication

### Example Test Cases
```elixir
test "static option provider loads values correctly"
test "domain option provider queries correct domain"
test "enum option provider detects Ecto.Enum values"
test "filter validates selections against options"
test "SelectoDome enforces option constraints"
```

## Documentation Updates

### User Guides
- How to configure select options in domains
- Best practices for option providers
- Performance considerations

### API Documentation
- Option provider types and configurations
- Filter form components
- Validation methods

### Examples
- Real-world domain configurations
- SelectoKino notebook examples
- Performance optimization patterns

## Migration Path

### Phase 1: Core Infrastructure (Week 1-2)
1. Implement domain configuration schema
2. Add SelectoMix detection capabilities
3. Create basic filter type support

### Phase 2: UI Implementation (Week 3-4)
1. Implement SelectoComponents filter forms
2. Add option loading infrastructure
3. Create multi-select components

### Phase 3: Integration (Week 5-6)
1. SelectoDome validation integration
2. SelectoKino interface implementation
3. Performance optimizations

### Phase 4: Polish & Documentation (Week 7-8)
1. Comprehensive testing
2. Documentation updates
3. Example implementations
4. Performance tuning

## Success Criteria

- ✅ Users can configure select-based filters in domain definitions
- ✅ SelectoMix automatically detects enum and reference fields
- ✅ SelectoComponents provides intuitive multi-select interfaces
- ✅ SelectoDome validates data against option constraints
- ✅ SelectoKino supports interactive option selection
- ✅ Performance remains acceptable with large option sets
- ✅ Backward compatibility is maintained
- ✅ Comprehensive documentation and examples provided