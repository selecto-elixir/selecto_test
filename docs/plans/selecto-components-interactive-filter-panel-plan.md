# SelectoComponents Interactive Filter Panel Plan

## Overview

Enhance SelectoComponents with an interactive filter panel that displays at the top of views, allowing users to dynamically add and configure filters. Filters defined in the view configuration can be marked as "user-configurable" with custom captions and will only be applied when users provide input values.

## Current State Analysis

### Existing Filter Limitations
- Filters are hard-coded in view configuration and always applied
- No user interface for dynamic filter modification
- Users cannot add additional filters beyond those predefined
- No distinction between required filters and optional user filters
- Filter labels are tied to field names without customization

### Current Filter Structure
```elixir
# Current static filter configuration
filters: [
  {"status", "active"},           # Always applied
  {"region", "North America"},    # Always applied
  {"date_created", {:gte, ~D[2023-01-01]}}  # Always applied
]
```

## Architecture Design

### Enhanced Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── interactive_filters/                          # Interactive filter system
│   ├── filter_panel.ex                          # Main filter panel component
│   ├── filter_builder.ex                        # Dynamic filter builder interface
│   ├── filter_renderer.ex                       # Render individual filter controls
│   ├── filter_state_manager.ex                  # Manage filter state and application
│   └── filter_persistence.ex                    # Save/load user filter preferences
├── filter_controls/                              # Filter input components
│   ├── text_filter.ex                           # Text search filter
│   ├── select_filter.ex                         # Dropdown selection filter
│   ├── multi_select_filter.ex                   # Multiple selection filter
│   ├── date_range_filter.ex                     # Date range picker
│   ├── number_range_filter.ex                   # Number range slider
│   ├── boolean_filter.ex                        # Toggle/checkbox filter
│   └── custom_filter.ex                         # Custom filter implementations
├── filter_logic/                                 # Filter application logic
│   ├── filter_compiler.ex                       # Compile filters to Selecto queries
│   ├── filter_validator.ex                      # Validate filter inputs
│   └── filter_optimizer.ex                      # Optimize filter queries
└── hooks/                                        # JavaScript enhancements
    ├── filter_panel_interactions.js             # Filter panel UI interactions
    ├── dynamic_filter_builder.js                # Add/remove filters dynamically
    └── filter_state_persistence.js              # Client-side filter state management
```

### API Design

#### Enhanced View Configuration with Interactive Filters
```elixir
# Enhanced view configuration with interactive filter support
view_config = %{
  type: :aggregate,
  selecto: base_query,
  group_by: ["region", "category"],
  aggregates: [{"total_sales", %{"format" => "sum"}}],
  
  # Enhanced filter configuration
  filters: %{
    # Required filters (always applied)
    required: [
      %{
        field: "status",
        operator: :equals,
        value: "active",
        description: "Only show active records"
      }
    ],
    
    # Optional user-configurable filters
    optional: [
      %{
        field: "region",
        type: :multi_select,
        caption: "Sales Region",
        description: "Filter by one or more sales regions",
        user_configurable: true,
        
        # Filter control configuration
        control: %{
          type: :multi_select,
          options: ["North America", "Europe", "Asia Pacific", "Latin America"],
          placeholder: "Select regions...",
          allow_search: true,
          max_selections: nil
        },
        
        # Query application
        query: %{
          operator: :in,
          field: "region",
          transform: nil  # Optional value transformation function
        }
      },
      
      %{
        field: "date_range",
        type: :date_range,
        caption: "Date Range", 
        description: "Filter records by date range",
        user_configurable: true,
        
        control: %{
          type: :date_range_picker,
          format: "YYYY-MM-DD",
          presets: [
            %{label: "Last 7 days", value: {:relative, -7, :days}},
            %{label: "Last 30 days", value: {:relative, -30, :days}},
            %{label: "This month", value: {:relative, :current_month}},
            %{label: "Last month", value: {:relative, :last_month}}
          ],
          allow_custom: true
        },
        
        query: %{
          operator: :between,
          field: "created_at",
          transform: &date_range_transform/1
        }
      },
      
      %{
        field: "sales_amount",
        type: :number_range,
        caption: "Sales Amount Range",
        description: "Filter by sales amount range",
        user_configurable: true,
        
        control: %{
          type: :range_slider,
          min: 0,
          max: 100000,
          step: 1000,
          format: :currency,
          show_inputs: true
        },
        
        query: %{
          operator: :between,
          field: "total_sales",
          transform: &currency_transform/1
        }
      },
      
      %{
        field: "search_text",
        type: :text_search,
        caption: "Search",
        description: "Search across customer names and descriptions",
        user_configurable: true,
        
        control: %{
          type: :search_input,
          placeholder: "Search customers...",
          debounce_ms: 500,
          min_length: 2,
          search_icon: true,
          clear_button: true
        },
        
        query: %{
          operator: :ilike,
          fields: ["customer_name", "description"],  # Multi-field search
          transform: &search_transform/1  # Add % wildcards
        }
      }
    ],
    
    # Dynamic filters (user can add from available fields)
    dynamic: %{
      enabled: true,
      available_fields: [
        %{
          field: "customer_tier",
          caption: "Customer Tier",
          type: :select,
          options: ["Bronze", "Silver", "Gold", "Platinum"]
        },
        
        %{
          field: "product_category", 
          caption: "Product Category",
          type: :multi_select,
          options_source: :query,  # Load options from database
          options_query: "SELECT DISTINCT category FROM products ORDER BY category"
        }
      ]
    }
  },
  
  # Filter panel configuration
  filter_panel: %{
    enabled: true,
    position: :top,  # :top, :left, :right, :bottom
    collapsible: true,
    initially_collapsed: false,
    
    # Layout options
    layout: %{
      columns: :auto,  # :auto, 1, 2, 3, 4
      responsive: true,
      compact_mode: false
    },
    
    # Interaction options
    interactions: %{
      auto_apply: true,          # Apply filters as user types
      apply_button: false,       # Show "Apply Filters" button
      clear_all_button: true,    # Show "Clear All" button
      reset_button: true,        # Show "Reset to Defaults" button
      
      # Advanced options
      save_preferences: true,    # Remember user's filter choices
      share_filters: true,       # Generate shareable URLs with filters
      export_with_filters: true  # Include filters in exports
    },
    
    # Visual styling
    styling: %{
      background: "var(--color-neutral-50)",
      border: "1px solid var(--color-neutral-200)",
      border_radius: "var(--radius-md)",
      padding: "var(--spacing-4)",
      shadow: "var(--shadow-sm)"
    }
  }
}
```

#### Filter State Management
```elixir
# Filter state structure
filter_state = %{
  # Currently active filters with user values
  active_filters: %{
    "region" => %{
      field: "region",
      operator: :in,
      value: ["North America", "Europe"],
      applied: true,
      user_modified: true
    },
    
    "date_range" => %{
      field: "date_range", 
      operator: :between,
      value: [~D[2023-01-01], ~D[2023-12-31]],
      applied: true,
      user_modified: true
    },
    
    "search_text" => %{
      field: "search_text",
      operator: :ilike,
      value: "tech",
      applied: true,
      user_modified: true
    }
  },
  
  # Available filters that can be added
  available_filters: [
    %{field: "customer_tier", caption: "Customer Tier", type: :select},
    %{field: "product_category", caption: "Product Category", type: :multi_select}
  ],
  
  # Filter panel state
  panel_state: %{
    collapsed: false,
    layout: :auto,
    last_applied: ~U[2023-01-15 10:30:00Z]
  },
  
  # User preferences
  preferences: %{
    auto_apply: true,
    remember_filters: true,
    default_filters: %{"region" => ["North America"]}
  }
}
```

## Filter Panel Implementation

### 1. Main Filter Panel Component
```elixir
defmodule SelectoComponents.InteractiveFilters.FilterPanel do
  use SelectoComponents, :component
  
  def render_filter_panel(assigns) do
    ~H"""
    <div class={[
      "filter-panel",
      filter_panel_classes(@config.filter_panel),
      collapsed_class(@filter_state.panel_state.collapsed)
    ]}>
      <!-- Filter panel header -->
      <div class="filter-panel-header">
        <div class="filter-panel-title">
          <.icon name="funnel" />
          <span>Filters</span>
          
          <%= if @filter_state.active_filters |> map_size() > 0 do %>
            <span class="active-filter-count">
              (<%= @filter_state.active_filters |> map_size() %>)
            </span>
          <% end %>
        </div>
        
        <div class="filter-panel-actions">
          <!-- Add filter dropdown -->
          <%= if @config.filters.dynamic.enabled do %>
            <.dropdown>
              <:trigger>
                <button class="add-filter-btn" type="button">
                  <.icon name="plus" />
                  Add Filter
                </button>
              </:trigger>
              
              <:content>
                <div class="available-filters">
                  <%= for available_filter <- @filter_state.available_filters do %>
                    <button 
                      class="filter-option"
                      phx-click="add_dynamic_filter"
                      phx-value-field={available_filter.field}
                      type="button"
                    >
                      <%= available_filter.caption %>
                    </button>
                  <% end %>
                </div>
              </:content>
            </.dropdown>
          <% end %>
          
          <!-- Panel actions -->
          <button 
            class="clear-filters-btn"
            phx-click="clear_all_filters"
            disabled={map_size(@filter_state.active_filters) == 0}
            type="button"
          >
            Clear All
          </button>
          
          <button 
            class="collapse-toggle"
            phx-click="toggle_filter_panel"
            type="button"
          >
            <.icon name={collapse_icon(@filter_state.panel_state.collapsed)} />
          </button>
        </div>
      </div>
      
      <!-- Filter controls -->
      <div 
        class="filter-panel-content"
        style={display_style(@filter_state.panel_state.collapsed)}
      >
        <div class={filter_grid_classes(@config.filter_panel.layout)}>
          <!-- Optional filters (user-configurable) -->
          <%= for {filter_id, filter_config} <- @config.filters.optional do %>
            <%= if filter_config.user_configurable do %>
              <.render_filter_control
                filter_id={filter_id}
                filter_config={filter_config}
                filter_state={Map.get(@filter_state.active_filters, filter_id)}
              />
            <% end %>
          <% end %>
          
          <!-- Dynamic filters (added by user) -->
          <%= for {filter_id, active_filter} <- @filter_state.active_filters do %>
            <%= if active_filter.user_added do %>
              <.render_dynamic_filter_control
                filter_id={filter_id}
                active_filter={active_filter}
              />
            <% end %>
          <% end %>
        </div>
        
        <!-- Filter panel footer -->
        <%= if not @config.filter_panel.interactions.auto_apply do %>
          <div class="filter-panel-footer">
            <button 
              class="apply-filters-btn btn-primary"
              phx-click="apply_filters"
              disabled={not filters_changed?(@filter_state)}
              type="button"
            >
              Apply Filters
            </button>
            
            <button 
              class="reset-filters-btn btn-secondary"
              phx-click="reset_filters"
              type="button"
            >
              Reset
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Individual filter control renderer
  def render_filter_control(assigns) do
    filter_type = assigns.filter_config.type
    
    assigns = assign(assigns, :component, get_filter_component(filter_type))
    
    ~H"""
    <div class="filter-control-container">
      <label class="filter-label">
        <%= @filter_config.caption %>
        <%= if @filter_config.description do %>
          <.tooltip content={@filter_config.description}>
            <.icon name="information-circle" class="help-icon" />
          </.tooltip>
        <% end %>
      </label>
      
      <div class="filter-control">
        <%= render_slot(@component, @filter_config, @filter_state) %>
        
        <!-- Clear individual filter -->
        <%= if @filter_state && @filter_state.applied do %>
          <button 
            class="clear-filter-btn"
            phx-click="clear_filter"
            phx-value-filter-id={@filter_id}
            type="button"
          >
            <.icon name="x-mark" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end
```

### 2. Filter Control Components
```elixir
defmodule SelectoComponents.FilterControls.MultiSelectFilter do
  use SelectoComponents, :component
  
  def render_multi_select_filter(assigns) do
    ~H"""
    <div class="multi-select-filter" x-data="multiSelectFilter()">
      <div class="multi-select-trigger" x-on:click="open = !open">
        <div class="selected-values">
          <%= if Enum.empty?(@filter_state.value || []) do %>
            <span class="placeholder"><%= @filter_config.control.placeholder %></span>
          <% else %>
            <%= for value <- @filter_state.value do %>
              <span class="selected-tag">
                <%= value %>
                <button 
                  x-on:click.stop=""
                  phx-click="remove_filter_value"
                  phx-value-filter-id={@filter_id}
                  phx-value-value={value}
                  type="button"
                >
                  <.icon name="x-mark" />
                </button>
              </span>
            <% end %>
          <% end %>
        </div>
        
        <.icon name="chevron-down" class="dropdown-arrow" />
      </div>
      
      <div 
        class="multi-select-dropdown"
        x-show="open"
        x-on:click.outside="open = false"
      >
        <%= if @filter_config.control.allow_search do %>
          <div class="search-box">
            <input 
              type="text"
              placeholder="Search options..."
              x-model="searchTerm"
              class="search-input"
            />
          </div>
        <% end %>
        
        <div class="options-list">
          <%= for option <- @filter_config.control.options do %>
            <label class="option-item">
              <input 
                type="checkbox"
                checked={option in (@filter_state.value || [])}
                phx-click="toggle_filter_value"
                phx-value-filter-id={@filter_id}
                phx-value-value={option}
              />
              <span class="option-label"><%= option %></span>
            </label>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

defmodule SelectoComponents.FilterControls.DateRangeFilter do
  use SelectoComponents, :component
  
  def render_date_range_filter(assigns) do
    ~H"""
    <div class="date-range-filter">
      <!-- Preset buttons -->
      <%= if @filter_config.control.presets do %>
        <div class="date-presets">
          <%= for preset <- @filter_config.control.presets do %>
            <button 
              class={["preset-btn", active_preset_class(preset, @filter_state)]}
              phx-click="apply_date_preset"
              phx-value-filter-id={@filter_id}
              phx-value-preset={Jason.encode!(preset.value)}
              type="button"
            >
              <%= preset.label %>
            </button>
          <% end %>
        </div>
      <% end %>
      
      <!-- Custom date range -->
      <%= if @filter_config.control.allow_custom do %>
        <div class="custom-date-range">
          <div class="date-input-group">
            <label>From</label>
            <input 
              type="date"
              value={format_date(@filter_state.value && elem(@filter_state.value, 0))}
              phx-change="update_date_range_start"
              phx-value-filter-id={@filter_id}
              class="date-input"
            />
          </div>
          
          <div class="date-input-group">
            <label>To</label>
            <input 
              type="date"
              value={format_date(@filter_state.value && elem(@filter_state.value, 1))}
              phx-change="update_date_range_end"
              phx-value-filter-id={@filter_id}
              class="date-input"
            />
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end

defmodule SelectoComponents.FilterControls.TextSearchFilter do
  use SelectoComponents, :component
  
  def render_text_search_filter(assigns) do
    ~H"""
    <div class="text-search-filter">
      <div class="search-input-container">
        <%= if @filter_config.control.search_icon do %>
          <.icon name="magnifying-glass" class="search-icon" />
        <% end %>
        
        <input 
          type="text"
          value={@filter_state.value || ""}
          placeholder={@filter_config.control.placeholder}
          phx-keyup="update_text_filter"
          phx-value-filter-id={@filter_id}
          phx-debounce={@filter_config.control.debounce_ms}
          class="search-input"
        />
        
        <%= if @filter_config.control.clear_button && @filter_state.value do %>
          <button 
            class="clear-search-btn"
            phx-click="clear_filter"
            phx-value-filter-id={@filter_id}
            type="button"
          >
            <.icon name="x-mark" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end

defmodule SelectoComponents.FilterControls.NumberRangeFilter do
  use SelectoComponents, :component
  
  def render_number_range_filter(assigns) do
    ~H"""
    <div class="number-range-filter">
      <!-- Range slider -->
      <div class="range-slider-container">
        <input 
          type="range"
          min={@filter_config.control.min}
          max={@filter_config.control.max}
          step={@filter_config.control.step}
          value={get_range_min(@filter_state.value, @filter_config.control)}
          phx-change="update_range_min"
          phx-value-filter-id={@filter_id}
          class="range-slider range-min"
        />
        
        <input 
          type="range"
          min={@filter_config.control.min}
          max={@filter_config.control.max}
          step={@filter_config.control.step}
          value={get_range_max(@filter_state.value, @filter_config.control)}
          phx-change="update_range_max"
          phx-value-filter-id={@filter_id}
          class="range-slider range-max"
        />
      </div>
      
      <!-- Value display/inputs -->
      <%= if @filter_config.control.show_inputs do %>
        <div class="range-inputs">
          <div class="range-input-group">
            <label>Min</label>
            <input 
              type="number"
              min={@filter_config.control.min}
              max={@filter_config.control.max}
              step={@filter_config.control.step}
              value={get_range_min(@filter_state.value, @filter_config.control)}
              phx-change="update_range_min_input"
              phx-value-filter-id={@filter_id}
              class="range-input"
            />
          </div>
          
          <div class="range-input-group">
            <label>Max</label>
            <input 
              type="number"
              min={@filter_config.control.min}
              max={@filter_config.control.max}
              step={@filter_config.control.step}
              value={get_range_max(@filter_state.value, @filter_config.control)}
              phx-change="update_range_max_input"
              phx-value-filter-id={@filter_id}
              class="range-input"
            />
          </div>
        </div>
      <% else %>
        <div class="range-display">
          <%= format_range_value(@filter_state.value, @filter_config.control) %>
        </div>
      <% end %>
    </div>
    """
  end
end
```

### 3. Filter State Management
```elixir
defmodule SelectoComponents.InteractiveFilters.FilterStateManager do
  @moduledoc """
  Manage filter state and application to queries.
  """
  
  def apply_filters_to_query(selecto_query, filter_state) do
    filter_state.active_filters
    |> Enum.filter(fn {_id, filter} -> filter.applied and has_value?(filter.value) end)
    |> Enum.reduce(selecto_query, fn {_id, filter}, query ->
         apply_single_filter(query, filter)
       end)
  end
  
  defp apply_single_filter(query, filter) do
    case filter.operator do
      :equals ->
        Selecto.filter(query, [{filter.field, filter.value}])
        
      :in ->
        Selecto.filter(query, [{filter.field, {:in, filter.value}}])
        
      :between ->
        [min_val, max_val] = filter.value
        query
        |> Selecto.filter([{filter.field, {:gte, min_val}}])
        |> Selecto.filter([{filter.field, {:lte, max_val}}])
        
      :ilike ->
        # Handle multi-field search
        case filter.fields do
          nil -> 
            Selecto.filter(query, [{filter.field, {:ilike, "%#{filter.value}%"}}])
            
          fields when is_list(fields) ->
            # Create OR condition for multiple fields
            or_conditions = Enum.map(fields, fn field ->
              {field, {:ilike, "%#{filter.value}%"}}
            end)
            Selecto.filter(query, [{:or, or_conditions}])
        end
        
      :custom ->
        # Apply custom filter function
        filter.apply_function.(query, filter.value)
    end
  end
  
  def update_filter_state(current_state, filter_id, new_value) do
    updated_filters = Map.update(current_state.active_filters, filter_id, 
      %{field: filter_id, value: new_value, applied: has_value?(new_value), user_modified: true},
      fn existing_filter ->
        %{existing_filter | 
          value: new_value, 
          applied: has_value?(new_value),
          user_modified: true
        }
      end
    )
    
    %{current_state | active_filters: updated_filters}
  end
  
  def add_dynamic_filter(current_state, field_config) do
    new_filter = %{
      field: field_config.field,
      operator: determine_operator(field_config.type),
      value: nil,
      applied: false,
      user_added: true,
      user_modified: false,
      config: field_config
    }
    
    updated_filters = Map.put(current_state.active_filters, field_config.field, new_filter)
    
    %{current_state | active_filters: updated_filters}
  end
  
  def remove_filter(current_state, filter_id) do
    updated_filters = Map.delete(current_state.active_filters, filter_id)
    %{current_state | active_filters: updated_filters}
  end
  
  def clear_all_filters(current_state) do
    # Keep required filters, clear optional ones
    cleared_filters = current_state.active_filters
      |> Enum.reject(fn {_id, filter} -> filter.user_modified or filter.user_added end)
      |> Enum.into(%{})
    
    %{current_state | active_filters: cleared_filters}
  end
  
  defp has_value?(nil), do: false
  defp has_value?(""), do: false
  defp has_value?([]), do: false
  defp has_value?(_), do: true
  
  defp determine_operator(:select), do: :equals
  defp determine_operator(:multi_select), do: :in
  defp determine_operator(:date_range), do: :between
  defp determine_operator(:number_range), do: :between
  defp determine_operator(:text_search), do: :ilike
  defp determine_operator(:boolean), do: :equals
end
```

## LiveView Integration

### Enhanced LiveView with Filter Panel
```elixir
defmodule SelectoTestWeb.EnhancedPagilaLive do
  use SelectoTestWeb, :live_view
  
  def mount(_params, _session, socket) do
    # Initialize with enhanced filter configuration
    view_config = build_enhanced_view_config()
    initial_filter_state = initialize_filter_state(view_config)
    
    socket = socket
      |> assign(:view_config, view_config)
      |> assign(:filter_state, initial_filter_state)
      |> assign(:results, [])
      |> load_data()
    
    {:ok, socket}
  end
  
  # Filter panel event handlers
  def handle_event("add_dynamic_filter", %{"field" => field}, socket) do
    field_config = find_available_filter(socket.assigns.view_config, field)
    
    updated_filter_state = FilterStateManager.add_dynamic_filter(
      socket.assigns.filter_state, 
      field_config
    )
    
    socket = socket
      |> assign(:filter_state, updated_filter_state)
      |> maybe_reload_data()
    
    {:noreply, socket}
  end
  
  def handle_event("update_text_filter", %{"filter-id" => filter_id, "value" => value}, socket) do
    updated_filter_state = FilterStateManager.update_filter_state(
      socket.assigns.filter_state,
      filter_id,
      value
    )
    
    socket = socket
      |> assign(:filter_state, updated_filter_state)
      |> maybe_reload_data()
    
    {:noreply, socket}
  end
  
  def handle_event("toggle_filter_value", %{"filter-id" => filter_id, "value" => value}, socket) do
    current_values = get_current_filter_values(socket.assigns.filter_state, filter_id)
    
    new_values = if value in current_values do
      List.delete(current_values, value)
    else
      [value | current_values]
    end
    
    updated_filter_state = FilterStateManager.update_filter_state(
      socket.assigns.filter_state,
      filter_id,
      new_values
    )
    
    socket = socket
      |> assign(:filter_state, updated_filter_state)
      |> maybe_reload_data()
    
    {:noreply, socket}
  end
  
  def handle_event("clear_filter", %{"filter-id" => filter_id}, socket) do
    updated_filter_state = FilterStateManager.update_filter_state(
      socket.assigns.filter_state,
      filter_id,
      nil
    )
    
    socket = socket
      |> assign(:filter_state, updated_filter_state)
      |> maybe_reload_data()
    
    {:noreply, socket}
  end
  
  def handle_event("clear_all_filters", _params, socket) do
    updated_filter_state = FilterStateManager.clear_all_filters(socket.assigns.filter_state)
    
    socket = socket
      |> assign(:filter_state, updated_filter_state)
      |> load_data()  # Force reload
    
    {:noreply, socket}
  end
  
  def handle_event("toggle_filter_panel", _params, socket) do
    current_collapsed = socket.assigns.filter_state.panel_state.collapsed
    
    updated_panel_state = %{
      socket.assigns.filter_state.panel_state | 
      collapsed: !current_collapsed
    }
    
    updated_filter_state = %{
      socket.assigns.filter_state | 
      panel_state: updated_panel_state
    }
    
    {:noreply, assign(socket, :filter_state, updated_filter_state)}
  end
  
  # Enhanced render with filter panel
  def render(assigns) do
    ~H"""
    <div class="enhanced-selecto-view">
      <!-- Interactive Filter Panel -->
      <SelectoComponents.InteractiveFilters.FilterPanel.render_filter_panel
        config={@view_config}
        filter_state={@filter_state}
      />
      
      <!-- Main Content Area -->
      <div class="main-content">
        <!-- Results Summary -->
        <div class="results-summary">
          <span class="result-count">
            <%= length(@results) %> results
            <%= if has_active_filters?(@filter_state) do %>
              <span class="filtered-indicator">(filtered)</span>
            <% end %>
          </span>
          
          <div class="view-actions">
            <button class="export-btn">Export</button>
            <button class="refresh-btn">Refresh</button>
          </div>
        </div>
        
        <!-- Data View -->
        <SelectoComponents.AggregateView.render
          data={@results}
          config={@view_config}
          styling={@view_config.styling}
        />
      </div>
    </div>
    """
  end
  
  # Helper functions
  defp maybe_reload_data(socket) do
    if socket.assigns.view_config.filter_panel.interactions.auto_apply do
      load_data(socket)
    else
      socket
    end
  end
  
  defp load_data(socket) do
    base_query = socket.assigns.view_config.selecto
    
    # Apply filters to query
    filtered_query = FilterStateManager.apply_filters_to_query(
      base_query, 
      socket.assigns.filter_state
    )
    
    # Execute query
    case Selecto.execute(filtered_query) do
      {:ok, {rows, _columns, _aliases}} ->
        assign(socket, :results, format_results(rows))
        
      {:error, reason} ->
        socket
        |> put_flash(:error, "Failed to load data: #{reason}")
        |> assign(:results, [])
    end
  end
end
```

## Implementation Phases

### Phase 1: Core Filter Panel (Week 1-3)
- [ ] Basic filter panel component with collapsible interface
- [ ] Filter state management system
- [ ] Core filter controls (text, select, multi-select)
- [ ] Integration with existing SelectoComponents views

### Phase 2: Advanced Filter Controls (Week 4-5)
- [ ] Date range picker with presets
- [ ] Number range slider with dual handles
- [ ] Boolean toggle and checkbox filters
- [ ] Dynamic filter addition interface

### Phase 3: Filter Logic and Optimization (Week 6-7)
- [ ] Filter compilation to Selecto queries
- [ ] Multi-field search functionality
- [ ] Filter validation and error handling
- [ ] Query optimization for complex filters

### Phase 4: User Experience and Persistence (Week 8-9)
- [ ] Filter state persistence across sessions
- [ ] URL integration with filter state
- [ ] Filter presets and saved configurations
- [ ] Responsive design for mobile devices

## Advanced Features

### Filter Presets and Saved Configurations
```elixir
# Filter preset system
filter_presets = %{
  # Built-in presets
  built_in: [
    %{
      name: "last_30_days",
      label: "Last 30 Days",
      description: "Data from the last 30 days",
      filters: %{
        "date_range" => {:relative, -30, :days},
        "status" => "active"
      }
    },
    
    %{
      name: "high_value_customers", 
      label: "High Value Customers",
      description: "Customers with >$10k total sales",
      filters: %{
        "total_sales" => {:gte, 10000},
        "customer_tier" => ["Gold", "Platinum"]
      }
    }
  ],
  
  # User-defined presets
  user_defined: [
    %{
      id: "user_preset_1",
      name: "my_custom_filter",
      label: "My Custom Filter",
      user_id: "user_123",
      filters: %{
        "region" => ["North America"],
        "date_range" => [~D[2023-01-01], ~D[2023-12-31]]
      },
      created_at: ~U[2023-01-15 10:00:00Z]
    }
  ]
}
```

### URL State Integration
```elixir
# URL parameter encoding for shareable filtered views
defmodule SelectoComponents.FilterUrlState do
  @moduledoc """
  Encode and decode filter state in URLs for sharing.
  """
  
  def encode_filter_state_to_url(filter_state, base_url) do
    encoded_filters = filter_state.active_filters
      |> Enum.filter(fn {_id, filter} -> filter.applied and has_value?(filter.value) end)
      |> Enum.map(fn {id, filter} -> {id, filter.value} end)
      |> Jason.encode!()
      |> Base.url_encode64()
    
    "#{base_url}?filters=#{encoded_filters}"
  end
  
  def decode_filter_state_from_url(url_params, view_config) do
    case Map.get(url_params, "filters") do
      nil -> initialize_default_filter_state(view_config)
      encoded_filters ->
        decoded_filters = encoded_filters
          |> Base.url_decode64!()
          |> Jason.decode!()
        
        apply_decoded_filters(decoded_filters, view_config)
    end
  end
end
```

### Performance Optimizations
```elixir
# Optimize filter queries and caching
performance_optimizations = %{
  # Query optimization
  query_optimization: %{
    filter_pushdown: true,        # Push filters down to database
    index_hints: true,            # Suggest optimal indexes
    query_plan_analysis: true,    # Analyze query performance
    batch_filter_application: true # Apply multiple filters efficiently
  },
  
  # Caching strategies
  caching: %{
    filter_result_cache: %{
      enabled: true,
      ttl: 300,  # 5 minutes
      key_strategy: :filter_hash
    },
    
    filter_option_cache: %{
      enabled: true,
      ttl: 3600,  # 1 hour  
      use_for: [:select_options, :multi_select_options]
    }
  },
  
  # UI performance
  ui_performance: %{
    debounce_text_filters: 500,   # 500ms debounce
    virtual_scroll_options: true, # Virtual scroll for large option lists
    lazy_load_options: true       # Load options on demand
  }
}
```

## Testing Strategy

### Component Tests
```elixir
test "filter panel renders with configured filters" do
  view_config = build_test_view_config_with_filters()
  filter_state = initialize_test_filter_state()
  
  html = render_component(FilterPanel, 
    config: view_config,
    filter_state: filter_state
  )
  
  # Test filter panel structure
  assert html =~ "filter-panel"
  assert html =~ "Add Filter"
  assert html =~ "Clear All"
  
  # Test individual filter controls
  assert html =~ "multi-select-filter"
  assert html =~ "date-range-filter"
  assert html =~ "text-search-filter"
end

test "filter state updates correctly" do
  initial_state = initialize_test_filter_state()
  
  # Update text filter
  updated_state = FilterStateManager.update_filter_state(
    initial_state,
    "search_text", 
    "test query"
  )
  
  assert updated_state.active_filters["search_text"].value == "test query"
  assert updated_state.active_filters["search_text"].applied == true
  assert updated_state.active_filters["search_text"].user_modified == true
end

test "filters are applied to Selecto query correctly" do
  filter_state = %{
    active_filters: %{
      "region" => %{
        field: "region",
        operator: :in,
        value: ["North America", "Europe"],
        applied: true
      },
      "date_range" => %{
        field: "created_at",
        operator: :between,
        value: [~D[2023-01-01], ~D[2023-12-31]],
        applied: true
      }
    }
  }
  
  base_query = build_test_selecto_query()
  filtered_query = FilterStateManager.apply_filters_to_query(base_query, filter_state)
  
  {sql, params} = Selecto.to_sql(filtered_query)
  
  assert sql =~ "region IN"
  assert sql =~ "created_at >= "
  assert sql =~ "created_at <= "
end
```

### Integration Tests
```elixir
test "live view handles filter interactions" do
  {:ok, view, _html} = live(conn, "/enhanced-pagila")
  
  # Test adding a text filter
  view
  |> form("form[phx-keyup='update_text_filter']")
  |> render_keyup(%{value: "test search", "filter-id" => "search_text"})
  
  # Should update results
  assert has_element?(view, ".filtered-indicator")
  
  # Test clearing filter
  view
  |> element("button[phx-click='clear_filter'][phx-value-filter-id='search_text']")
  |> render_click()
  
  refute has_element?(view, ".filtered-indicator")
end

test "filter state persists across page reloads" do
  {:ok, view, _html} = live(conn, "/enhanced-pagila")
  
  # Apply filters
  apply_test_filters(view)
  
  # Get current URL with filter state
  current_url = get_current_url(view)
  
  # Navigate to URL directly
  {:ok, view2, _html} = live(conn, current_url)
  
  # Should have filters applied
  assert has_active_filters?(view2)
end
```

## Documentation Requirements

- [ ] Complete API reference for interactive filter configuration
- [ ] Filter control component documentation with examples
- [ ] Integration guide for existing SelectoComponents implementations
- [ ] Performance optimization guide for complex filter scenarios
- [ ] User experience best practices for filter panel design

## Success Metrics

- [ ] All major filter types implemented (text, select, date, number, boolean)
- [ ] Filter panel integrates seamlessly with existing SelectoComponents views
- [ ] Dynamic filter addition works with real-time query updates
- [ ] Filter state persistence works across browser sessions
- [ ] Performance maintains <500ms filter application time
- [ ] URL integration enables shareable filtered views
- [ ] Mobile-responsive filter panel design
- [ ] Zero breaking changes to existing SelectoComponents API
- [ ] Comprehensive test coverage including user interactions (>95%)