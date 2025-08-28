# SelectoComponents Enhanced Forms Plan

## Overview

Enhance SelectoComponents' view definition and filter selection forms with modern UI patterns, better user experience, drag-and-drop interfaces, smart field suggestions, validation, and real-time preview capabilities.

## Current State Analysis

### Existing Form Limitations
- Basic HTML form inputs with minimal interactivity
- Limited field type support (text, select, checkbox only)
- No visual feedback or real-time preview
- Manual field entry without autocomplete or suggestions
- No drag-and-drop for field arrangement
- Basic validation with poor error messaging
- No form state persistence or sharing

### Current Form Structure
```elixir
# Current basic form rendering
def render_filter_form(assigns) do
  ~H"""
  <form phx-change="update_filters">
    <%= for filter <- @available_filters do %>
      <div class="filter-input">
        <label><%= filter.name %></label>
        <input type="text" name={filter.field} value={filter.value} />
      </div>
    <% end %>
    <button type="submit">Apply Filters</button>
  </form>
  """
end
```

## Architecture Design

### Enhanced Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── enhanced_forms/                               # Enhanced forms namespace
│   ├── view_definition_form.ex                  # Enhanced view configuration form
│   ├── filter_selection_form.ex                 # Advanced filter building form
│   ├── field_selector.ex                        # Smart field selection component
│   ├── filter_builder.ex                        # Visual filter construction
│   ├── form_preview.ex                          # Real-time preview component
│   └── form_persistence.ex                      # Save/load form configurations
├── form_inputs/                                  # Advanced input components
│   ├── smart_select.ex                          # Searchable, grouped select
│   ├── multi_select.ex                          # Multi-value selection
│   ├── date_picker.ex                           # Advanced date/time picker
│   ├── range_slider.ex                          # Numeric range input
│   ├── tag_input.ex                             # Tag-based input
│   ├── conditional_input.ex                     # Show/hide based on conditions
│   └── field_mapping.ex                         # Drag-and-drop field mapping
├── form_builders/                                # Specialized form builders
│   ├── aggregate_builder.ex                     # Aggregate query builder
│   ├── join_builder.ex                          # Visual join configuration
│   ├── sort_builder.ex                          # Drag-and-drop sort configuration
│   └── group_by_builder.ex                      # Group by field selection
└── hooks/                                        # JavaScript enhancements
    ├── form_interactions.js                     # Advanced form interactions
    ├── drag_drop_fields.js                      # Drag-and-drop functionality
    ├── real_time_preview.js                     # Live preview updates
    ├── form_validation.js                       # Enhanced validation
    └── form_persistence.js                      # Auto-save and sharing
```

### API Design

#### Enhanced View Definition Form
```elixir
# Comprehensive view definition form
view_definition_config = %{
  # Form sections
  sections: [
    %{
      name: "data_source",
      title: "Data Source",
      description: "Configure your data source and primary table",
      fields: [
        %{
          name: "domain",
          type: :domain_selector,
          required: true,
          description: "Select the primary data domain"
        },
        %{
          name: "view_type", 
          type: :radio_group,
          options: [
            %{value: "aggregate", label: "Aggregate View", description: "Summarized data with grouping"},
            %{value: "detail", label: "Detail View", description: "Individual record details"}
          ],
          default: "aggregate"
        }
      ]
    },
    
    %{
      name: "field_selection",
      title: "Field Selection",
      description: "Choose which fields to display",
      component: :field_selector,
      features: %{
        drag_drop: true,
        search_fields: true,
        field_preview: true,
        grouping: true  # Group fields by table/category
      }
    },
    
    %{
      name: "filtering",
      title: "Filters",
      description: "Configure data filtering",
      component: :filter_builder,
      features: %{
        visual_builder: true,
        condition_groups: true,
        smart_suggestions: true
      }
    },
    
    %{
      name: "presentation",
      title: "Presentation",
      description: "Configure how data is displayed",
      fields: [
        %{
          name: "title",
          type: :text,
          placeholder: "View title (optional)"
        },
        %{
          name: "description",
          type: :textarea,
          placeholder: "View description (optional)"
        },
        %{
          name: "default_sort",
          type: :sort_builder,
          description: "Default sorting configuration"
        }
      ]
    }
  ],
  
  # Form behavior
  behavior: %{
    auto_save: true,
    save_interval: 30000,  # 30 seconds
    real_time_preview: true,
    validation: :live,  # :live, :on_submit, :off
    progress_indicator: true
  },
  
  # Preview configuration
  preview: %{
    enabled: true,
    sample_size: 10,
    refresh_interval: 5000,  # 5 seconds
    show_query: true,  # Show generated SQL
    position: :sidebar  # :sidebar, :modal, :bottom
  }
}
```

#### Advanced Filter Builder
```elixir
# Visual filter construction interface
filter_builder_config = %{
  # Filter building interface
  interface: %{
    type: :visual_builder,  # :visual_builder, :text_input, :hybrid
    layout: :tree,  # :tree, :list, :grid
    
    # Drag and drop configuration
    drag_drop: %{
      enabled: true,
      field_palette: true,    # Draggable field palette
      operator_palette: true, # Draggable operators
      nested_conditions: true # Support for nested AND/OR groups
    }
  },
  
  # Available filter types
  filter_types: %{
    # Text filters
    text: %{
      operators: ["equals", "contains", "starts_with", "ends_with", "regex"],
      features: ["autocomplete", "case_sensitivity", "fuzzy_match"]
    },
    
    # Numeric filters
    numeric: %{
      operators: ["equals", "greater_than", "less_than", "between", "in_list"],
      input_types: ["number", "slider", "range_slider"],
      features: ["unit_conversion", "percentage", "currency"]
    },
    
    # Date filters
    date: %{
      operators: ["equals", "after", "before", "between", "relative"],
      input_types: ["date_picker", "relative_picker", "calendar"],
      relative_options: ["today", "yesterday", "last_7_days", "last_30_days", "this_month", "last_month"],
      features: ["timezone_handling", "business_days_only"]
    },
    
    # List filters
    list: %{
      operators: ["in", "not_in", "contains_any", "contains_all"],
      input_types: ["multi_select", "tag_input", "checkbox_list"],
      features: ["search_within", "hierarchical_options", "option_grouping"]
    },
    
    # Boolean filters
    boolean: %{
      operators: ["is_true", "is_false", "is_null", "is_not_null"],
      input_types: ["toggle", "radio", "select"],
      features: ["three_state"]  # true/false/null
    }
  },
  
  # Smart suggestions
  suggestions: %{
    enabled: true,
    suggest_fields: true,      # Suggest relevant fields
    suggest_operators: true,   # Suggest appropriate operators
    suggest_values: true,      # Suggest values based on data
    learn_patterns: true       # Learn from user behavior
  },
  
  # Validation and feedback
  validation: %{
    real_time: true,
    show_warnings: true,      # Warn about performance issues
    suggest_indexes: true,    # Suggest database indexes
    validate_syntax: true     # Validate filter syntax
  }
}
```

#### Smart Field Selector
```elixir
# Intelligent field selection interface
field_selector_config = %{
  # Field organization
  organization: %{
    grouping: :by_table,  # :by_table, :by_type, :by_category, :alphabetical
    search: %{
      enabled: true,
      fuzzy_match: true,
      search_descriptions: true,
      highlight_matches: true
    },
    
    # Field categorization
    categories: %{
      "identifiers" => ["id", "uuid", "slug"],
      "personal_info" => ["name", "email", "phone", "address"],
      "timestamps" => ["created_at", "updated_at", "deleted_at"],
      "financial" => ["price", "cost", "total", "tax"],
      "status" => ["status", "state", "active", "published"]
    }
  },
  
  # Field information display
  field_info: %{
    show_data_type: true,
    show_description: true,
    show_sample_values: true,
    show_null_percentage: true,
    show_cardinality: true  # Unique value count
  },
  
  # Selection interface
  selection: %{
    interface: :drag_drop,  # :drag_drop, :checkbox, :dual_list
    multiple: true,
    preserve_order: true,
    max_selections: nil,
    
    # Selected field configuration
    field_configuration: %{
      editable_labels: true,
      custom_formatting: true,
      conditional_display: true,
      aggregation_options: true  # For aggregate views
    }
  },
  
  # Drag and drop behavior
  drag_drop: %{
    visual_feedback: true,
    drop_zones: ["selected_fields", "group_by", "sort_by"],
    reordering: true,
    copy_vs_move: "configurable"  # User can choose
  }
}
```

## Enhanced Form Components

### 1. Visual Filter Builder
```elixir
# Drag-and-drop filter construction
def render_visual_filter_builder(assigns) do
  ~H"""
  <div class="filter-builder" phx-hook="FilterBuilder">
    <!-- Field palette -->
    <div class="field-palette">
      <h4>Available Fields</h4>
      <div class="field-list" id="field-palette">
        <%= for field <- @available_fields do %>
          <div 
            class="draggable-field" 
            draggable="true"
            data-field={field.name}
            data-type={field.type}
          >
            <.icon name={field_type_icon(field.type)} />
            <%= field.label %>
            <span class="field-type"><%= field.type %></span>
          </div>
        <% end %>
      </div>
    </div>
    
    <!-- Filter construction area -->
    <div class="filter-canvas">
      <h4>Filter Conditions</h4>
      <div class="filter-groups" id="filter-canvas">
        <%= if Enum.empty?(@filter_groups) do %>
          <div class="empty-state">
            <p>Drag fields here to create filters</p>
            <.icon name="arrow-down" class="hint-arrow" />
          </div>
        <% else %>
          <%= for group <- @filter_groups do %>
            <.render_filter_group group={group} />
          <% end %>
        <% end %>
        
        <!-- Add group button -->
        <button 
          phx-click="add_filter_group" 
          class="add-group-btn"
          type="button"
        >
          <.icon name="plus" />
          Add Filter Group
        </button>
      </div>
    </div>
    
    <!-- Filter preview -->
    <div class="filter-preview">
      <h4>Generated Query</h4>
      <code class="sql-preview"><%= @generated_sql %></code>
      
      <div class="filter-stats">
        <span>Estimated results: ~<%= @estimated_results %></span>
        <%= if @performance_warning do %>
          <.alert type="warning">
            <.icon name="exclamation-triangle" />
            <%= @performance_warning %>
          </.alert>
        <% end %>
      </div>
    </div>
  </div>
  """
end

# Individual filter group component
def render_filter_group(assigns) do
  ~H"""
  <div class="filter-group" data-group-id={@group.id}>
    <div class="group-header">
      <select phx-change="change_group_operator" phx-value-group-id={@group.id}>
        <option value="and" selected={@group.operator == "and"}>AND</option>
        <option value="or" selected={@group.operator == "or"}>OR</option>
      </select>
      
      <button 
        phx-click="remove_filter_group" 
        phx-value-group-id={@group.id}
        class="remove-group-btn"
        type="button"
      >
        <.icon name="x-mark" />
      </button>
    </div>
    
    <div class="group-conditions">
      <%= for condition <- @group.conditions do %>
        <.render_filter_condition condition={condition} />
      <% end %>
      
      <!-- Drop zone for new conditions -->
      <div 
        class="condition-drop-zone" 
        phx-drop-target={@group.id}
        data-drop-type="condition"
      >
        Drop fields here to add conditions
      </div>
    </div>
  </div>
  """
end
```

### 2. Smart Field Selector with Search
```elixir
# Intelligent field selection with search and categorization
def render_smart_field_selector(assigns) do
  ~H"""
  <div class="field-selector" x-data="fieldSelector()">
    <!-- Search and filters -->
    <div class="field-selector-header">
      <div class="search-box">
        <.icon name="magnifying-glass" />
        <input 
          type="text" 
          placeholder="Search fields..."
          x-model="searchTerm"
          phx-keyup="search_fields"
          phx-debounce="300"
        />
      </div>
      
      <div class="field-filters">
        <select x-model="selectedCategory" phx-change="filter_by_category">
          <option value="">All Categories</option>
          <%= for {category, _fields} <- @field_categories do %>
            <option value={category}><%= humanize(category) %></option>
          <% end %>
        </select>
        
        <select x-model="selectedType" phx-change="filter_by_type">
          <option value="">All Types</option>
          <%= for type <- @available_types do %>
            <option value={type}><%= String.upcase(type) %></option>
          <% end %>
        </select>
      </div>
    </div>
    
    <!-- Available fields (organized by category) -->
    <div class="available-fields">
      <%= for {category, fields} <- @filtered_field_categories do %>
        <div class="field-category" x-show="categoryVisible('<%= category %>')">
          <h4 class="category-header">
            <.icon name="chevron-down" x-bind:class="{'rotate-180': !expanded}" />
            <%= humanize(category) %>
            <span class="field-count">(<%= length(fields) %>)</span>
          </h4>
          
          <div class="field-list" x-show="expanded">
            <%= for field <- fields do %>
              <div 
                class={["field-item", field_selected_class(field, @selected_fields)]}
                phx-click="toggle_field_selection"
                phx-value-field={field.name}
                draggable="true"
                data-field={field.name}
              >
                <div class="field-info">
                  <div class="field-header">
                    <.icon name={field_type_icon(field.type)} />
                    <span class="field-name"><%= field.label %></span>
                    <span class="field-type badge"><%= field.type %></span>
                  </div>
                  
                  <%= if field.description do %>
                    <p class="field-description"><%= field.description %></p>
                  <% end %>
                  
                  <div class="field-metadata">
                    <%= if field.sample_values do %>
                      <span class="sample-values">
                        Examples: <%= Enum.join(field.sample_values, ", ") %>
                      </span>
                    <% end %>
                    
                    <%= if field.null_percentage do %>
                      <span class="null-percentage">
                        <%= field.null_percentage %>% null
                      </span>
                    <% end %>
                  </div>
                </div>
                
                <!-- Selection checkbox -->
                <input 
                  type="checkbox" 
                  checked={field_selected?(field, @selected_fields)}
                  tabindex="-1"
                />
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    
    <!-- Selected fields configuration -->
    <div class="selected-fields" id="selected-fields-zone">
      <h4>Selected Fields (<%= length(@selected_fields) %>)</h4>
      
      <%= if Enum.empty?(@selected_fields) do %>
        <div class="empty-selection">
          <p>No fields selected</p>
          <p class="hint">Click fields above or drag them here</p>
        </div>
      <% else %>
        <div class="selected-field-list" phx-hook="SortableFields">
          <%= for {field, index} <- Enum.with_index(@selected_fields) do %>
            <div class="selected-field" data-field-index={index}>
              <div class="field-handle">
                <.icon name="grip-vertical" />
              </div>
              
              <div class="field-config">
                <div class="field-basic">
                  <span class="field-name"><%= field.label %></span>
                  <span class="field-type"><%= field.type %></span>
                </div>
                
                <!-- Field configuration options -->
                <div class="field-options" x-data="{expanded: false}">
                  <button 
                    x-on:click="expanded = !expanded"
                    class="expand-options"
                    type="button"
                  >
                    <.icon name="cog-6-tooth" />
                  </button>
                  
                  <div x-show="expanded" class="options-panel">
                    <!-- Custom label -->
                    <div class="option-group">
                      <label>Display Label</label>
                      <input 
                        type="text" 
                        value={field.label}
                        phx-change="update_field_label"
                        phx-value-field={field.name}
                      />
                    </div>
                    
                    <!-- Formatting options -->
                    <%= if field.type in ["number", "currency", "date", "datetime"] do %>
                      <div class="option-group">
                        <label>Format</label>
                        <.render_format_options field={field} />
                      </div>
                    <% end %>
                    
                    <!-- Aggregation options (for aggregate views) -->
                    <%= if @view_type == "aggregate" and field.type in ["number", "currency"] do %>
                      <div class="option-group">
                        <label>Aggregation</label>
                        <select 
                          phx-change="update_field_aggregation"
                          phx-value-field={field.name}
                        >
                          <option value="">None</option>
                          <option value="sum">Sum</option>
                          <option value="avg">Average</option>
                          <option value="min">Minimum</option>
                          <option value="max">Maximum</option>
                          <option value="count">Count</option>
                        </select>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
              
              <button 
                phx-click="remove_selected_field"
                phx-value-field={field.name}
                class="remove-field"
                type="button"
              >
                <.icon name="x-mark" />
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>
  """
end
```

### 3. Real-time Preview Panel
```elixir
# Live preview of query results
def render_form_preview(assigns) do
  ~H"""
  <div class="form-preview-panel" phx-hook="FormPreview">
    <div class="preview-header">
      <h3>Preview</h3>
      
      <div class="preview-controls">
        <button 
          phx-click="refresh_preview" 
          class="btn-sm"
          type="button"
          disabled={@preview_loading}
        >
          <%= if @preview_loading do %>
            <.spinner class="w-4 h-4" />
          <% else %>
            <.icon name="arrow-path" />
          <% end %>
          Refresh
        </button>
        
        <div class="preview-options">
          <label class="checkbox-label">
            <input 
              type="checkbox" 
              phx-click="toggle_show_query"
              checked={@show_query}
            />
            Show Query
          </label>
        </div>
      </div>
    </div>
    
    <!-- Generated SQL display -->
    <%= if @show_query do %>
      <div class="sql-preview">
        <h4>Generated SQL</h4>
        <code class="sql-code"><%= @generated_sql %></code>
        
        <div class="query-stats">
          <span>Estimated execution time: <%= @estimated_time %>ms</span>
          <span>Estimated result count: ~<%= @estimated_results %></span>
        </div>
      </div>
    <% end %>
    
    <!-- Preview results -->
    <div class="preview-results">
      <%= if @preview_loading do %>
        <div class="loading-state">
          <.spinner />
          <p>Loading preview...</p>
        </div>
      <% else %>
        <%= case @preview_data do %>
          <% {:ok, results} -> %>
            <div class="results-table">
              <table>
                <thead>
                  <tr>
                    <%= for field <- @selected_fields do %>
                      <th><%= field.label %></th>
                    <% end %>
                  </tr>
                </thead>
                <tbody>
                  <%= for row <- Enum.take(results, 5) do %>
                    <tr>
                      <%= for field <- @selected_fields do %>
                        <td><%= format_preview_value(row[field.name], field.type) %></td>
                      <% end %>
                    </tr>
                  <% end %>
                </tbody>
              </table>
              
              <%= if length(results) > 5 do %>
                <div class="preview-note">
                  Showing first 5 of <%= length(results) %> results
                </div>
              <% end %>
            </div>
            
          <% {:error, error} -> %>
            <div class="error-state">
              <.icon name="exclamation-triangle" />
              <p>Preview failed: <%= error %></p>
            </div>
            
          <% nil -> %>
            <div class="empty-state">
              <p>Configure your view to see preview</p>
            </div>
        <% end %>
      <% end %>
    </div>
  </div>
  """
end
```

## Advanced Form Features

### 1. Form Persistence and Sharing
```elixir
# Save and share form configurations
persistence_features = %{
  # Auto-save functionality
  auto_save: %{
    enabled: true,
    interval: 30000,  # 30 seconds
    storage: :local_storage,
    key_template: "form_config_{{form_type}}_{{timestamp}}"
  },
  
  # Manual save/load
  manual_save: %{
    enabled: true,
    save_locations: [:local_storage, :server, :export_file],
    naming_strategy: :user_defined,
    include_metadata: true  # Save timestamp, user, etc.
  },
  
  # Sharing and collaboration
  sharing: %{
    enabled: true,
    share_types: [:url, :json_export, :saved_view],
    permissions: [:view_only, :edit_copy, :full_edit],
    expiration: {:days, 30}
  },
  
  # Version history
  versioning: %{
    enabled: true,
    max_versions: 10,
    auto_version_on_save: true,
    diff_visualization: true
  }
}
```

### 2. Smart Suggestions and Autocomplete
```elixir
# Intelligent form assistance
suggestion_engine = %{
  # Field suggestions based on context
  field_suggestions: %{
    enabled: true,
    sources: [:schema_analysis, :common_patterns, :user_history],
    confidence_threshold: 0.7,
    max_suggestions: 5
  },
  
  # Filter value suggestions
  value_suggestions: %{
    enabled: true,
    strategies: [:data_sampling, :enum_values, :recent_values],
    cache_duration: {:minutes, 15},
    max_suggestions: 10
  },
  
  # Query optimization suggestions
  optimization_suggestions: %{
    enabled: true,
    suggest_indexes: true,
    warn_expensive_operations: true,
    suggest_aggregation_alternatives: true
  },
  
  # Learning from user behavior
  machine_learning: %{
    enabled: true,
    track_field_combinations: true,
    track_filter_patterns: true,
    adapt_suggestions: true
  }
}
```

### 3. Advanced Validation
```elixir
# Comprehensive form validation system
validation_system = %{
  # Real-time validation
  real_time: %{
    enabled: true,
    debounce_ms: 500,
    validate_on: [:change, :blur],
    show_success_states: true
  },
  
  # Validation rules
  rules: %{
    # Required fields
    required_fields: ["domain", "view_type"],
    
    # Field combinations
    field_dependencies: %{
      "aggregate_functions" => ["group_by_fields"],  # Aggregates require grouping
      "date_filters" => ["date_fields"]             # Date filters need date fields
    },
    
    # Performance validations
    performance_checks: %{
      max_selected_fields: 50,
      warn_large_result_sets: 10000,
      require_filters_for_large_tables: true
    },
    
    # Business rule validation
    business_rules: [
      {:custom, "validate_user_permissions", "User must have access to selected domains"},
      {:custom, "validate_data_sensitivity", "Check for sensitive data exposure"}
    ]
  },
  
  # Error messaging
  error_messaging: %{
    inline_errors: true,
    error_summary: true,
    helpful_suggestions: true,
    links_to_documentation: true
  }
}
```

## Implementation Phases

### Phase 1: Core Form Enhancement (Week 1-3)
- [ ] Enhanced view definition form with sections and progress
- [ ] Smart field selector with search and categorization
- [ ] Basic filter builder with visual interface
- [ ] Real-time form validation and error messaging

### Phase 2: Advanced Interactions (Week 4-5)
- [ ] Drag-and-drop functionality for field arrangement
- [ ] Visual filter builder with condition grouping
- [ ] Real-time preview panel with query display
- [ ] Form persistence (auto-save and manual save)

### Phase 3: Intelligence Features (Week 6-7)
- [ ] Smart suggestions based on context and data
- [ ] Autocomplete for field names and filter values
- [ ] Performance warnings and optimization suggestions
- [ ] Form sharing and collaboration features

### Phase 4: Polish and Integration (Week 8-9)
- [ ] Mobile-responsive form design
- [ ] Accessibility improvements (keyboard navigation, screen readers)
- [ ] Integration with existing SelectoComponents workflow
- [ ] Comprehensive testing and documentation

## Form User Experience

### Progressive Disclosure
```elixir
# Reveal complexity gradually
progressive_ux = %{
  # Start with simple options
  initial_view: :simplified,
  
  # Progressive revelation
  complexity_levels: [
    %{
      level: :basic,
      features: ["field_selection", "basic_filtering", "simple_sorting"]
    },
    %{
      level: :intermediate, 
      features: ["advanced_filtering", "grouping", "aggregation"]
    },
    %{
      level: :advanced,
      features: ["custom_functions", "complex_joins", "performance_tuning"]
    }
  ],
  
  # Adaptive interface
  adaptive: %{
    remember_user_level: true,
    suggest_upgrades: true,
    contextual_help: true
  }
}
```

### Mobile Optimization
```elixir
# Mobile-friendly form design
mobile_optimization = %{
  # Touch-friendly interactions
  touch_targets: %{
    min_size: "44px",
    spacing: "8px",
    drag_handles: "larger_on_mobile"
  },
  
  # Mobile-specific layouts
  mobile_layouts: %{
    field_selector: :accordion,  # Collapsible sections
    filter_builder: :wizard,     # Step-by-step wizard
    preview: :modal             # Full-screen modal
  },
  
  # Gesture support
  gestures: %{
    swipe_to_delete: true,
    pinch_to_zoom: true,  # For complex filter trees
    long_press_context: true
  }
}
```

## Testing Strategy

### Component Tests
```elixir
test "enhanced view definition form renders correctly" do
  config = enhanced_view_definition_config()
  
  html = render_component(ViewDefinitionForm, config: config)
  
  # Test form structure
  assert html =~ "view-definition-form"
  assert html =~ "data-source"
  assert html =~ "field-selection"
  assert html =~ "filtering"
  
  # Test progressive disclosure
  assert html =~ "form-progress"
  assert html =~ "section-navigation"
end

test "smart field selector with search works" do
  {:ok, view, _html} = live(conn, "/view-builder")
  
  # Search for fields
  view
  |> form("form[phx-change='search_fields']")  
  |> render_change(%{search_term: "email"})
  
  # Should show filtered results
  assert has_element?(view, "[data-field='email']")
  assert has_element?(view, "[data-field='email_verified']")
  refute has_element?(view, "[data-field='phone']")
end

test "visual filter builder creates correct filters" do
  {:ok, view, _html} = live(conn, "/filter-builder")
  
  # Drag field to create filter
  view
  |> element("[data-field='name']")
  |> render_hook("drag_start", %{field: "name", type: "string"})
  
  view
  |> element("[data-drop-type='condition']")
  |> render_hook("drop", %{field: "name", operator: "contains"})
  
  # Should create filter condition
  assert has_element?(view, ".filter-condition[data-field='name']")
  assert has_element?(view, "select[value='contains']")
end
```

### Integration Tests  
```elixir
test "form persistence saves and restores state" do
  {:ok, view, _html} = live(conn, "/view-builder")
  
  # Configure form
  configure_view_form(view, %{
    fields: ["name", "email"],
    filters: [%{field: "status", operator: "equals", value: "active"}]
  })
  
  # Trigger auto-save
  :timer.sleep(31000)  # Wait for auto-save interval
  
  # Reload page
  {:ok, view2, _html} = live(conn, "/view-builder")
  
  # Should restore previous state
  assert form_has_fields(view2, ["name", "email"])
  assert form_has_filter(view2, "status", "equals", "active")
end

test "real-time preview updates correctly" do
  {:ok, view, _html} = live(conn, "/view-builder")
  
  # Initial state - no preview
  refute has_element?(view, ".preview-results table")
  
  # Add fields
  add_fields(view, ["name", "email"])
  
  # Should trigger preview update
  assert_receive {:preview_updated, _data}
  assert has_element?(view, ".preview-results table")
  
  # Add filter
  add_filter(view, "status", "equals", "active")
  
  # Should update preview again
  assert_receive {:preview_updated, _filtered_data}
end
```

## Documentation Requirements

- [ ] Complete API reference for enhanced form components
- [ ] Form configuration guide with examples
- [ ] Best practices for form design and user experience
- [ ] Accessibility guidelines for form interactions
- [ ] Mobile optimization patterns and examples
- [ ] Integration guide with existing SelectoComponents workflow

## Success Metrics

- [ ] All enhanced form features implemented and tested
- [ ] Form completion time reduced by >50% compared to basic forms
- [ ] User error rates reduced by >60% through validation and suggestions
- [ ] Mobile-responsive design works across all device sizes
- [ ] Full accessibility compliance (WCAG 2.1 AA)
- [ ] Real-time preview updates within <500ms
- [ ] Form persistence works reliably across sessions
- [ ] Zero breaking changes to existing form implementations
- [ ] Comprehensive test coverage including accessibility tests (>95%)