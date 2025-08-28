# SelectoComponents Enhanced Table Presentation Plan

## Overview

Enhance SelectoComponents' aggregate and detail view table presentation with modern data table features including sorting, filtering, column management, export capabilities, responsive design, and advanced interaction patterns.

## Current State Analysis

### Existing Table Limitations
- Basic table rendering with minimal interactivity
- No built-in sorting or filtering capabilities
- Limited responsive design for mobile devices
- No column management (show/hide, reorder, resize)
- No export functionality
- Basic styling with limited customization
- No advanced selection or bulk operations

### Current Table Structure
```elixir
# Current basic table rendering
def render_table(assigns) do
  ~H"""
  <table class="selecto-table">
    <thead>
      <%= for field <- @fields do %>
        <th><%= field %></th>
      <% end %>
    </thead>
    <tbody>
      <%= for row <- @data do %>
        <tr>
          <%= for field <- @fields do %>
            <td><%= get_field_value(row, field) %></td>
          <% end %>
        </tr>
      <% end %>
    </tbody>
  </table>
  """
end
```

## Architecture Design

### Enhanced Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── enhanced_table/                               # Enhanced table namespace
│   ├── data_table.ex                            # Main enhanced table component
│   ├── table_header.ex                          # Enhanced header with sorting/filtering
│   ├── table_row.ex                             # Enhanced row with selection/actions
│   ├── table_cell.ex                            # Smart cell rendering with formatting
│   ├── column_manager.ex                        # Column visibility/ordering
│   ├── table_toolbar.ex                         # Search, filters, actions toolbar
│   ├── table_footer.ex                          # Pagination, summary, export
│   └── responsive_wrapper.ex                    # Mobile-responsive container
├── table_features/                               # Feature-specific modules
│   ├── sorting.ex                               # Multi-column sorting
│   ├── filtering.ex                             # Column-level filtering
│   ├── selection.ex                             # Row selection and bulk operations
│   ├── export.ex                                # Export functionality
│   ├── virtualization.ex                        # Virtual scrolling for large datasets
│   └── search.ex                                # Global search functionality
└── hooks/                                        # JavaScript enhancements
    ├── table_interactions.js                    # Sorting, filtering, selection
    ├── column_resize.js                         # Resizable columns
    ├── responsive_table.js                      # Mobile table interactions
    ├── virtual_scroll.js                        # Virtual scrolling
    └── export_handler.js                        # Client-side export functionality
```

### API Design

#### Enhanced Table Configuration
```elixir
# Enhanced table with comprehensive features
enhanced_table_config = %{
  # Data and basic configuration
  data: results,
  fields: ["name", "email", "created_at", "status", "total_orders"],
  
  # Table features
  features: %{
    sorting: %{
      enabled: true,
      multi_column: true,
      default_sort: [{"created_at", :desc}],
      sortable_fields: ["name", "email", "created_at", "total_orders"]
    },
    
    filtering: %{
      enabled: true,
      column_filters: true,
      global_search: true,
      filter_types: %{
        "name" => :text,
        "email" => :text,
        "status" => :select,
        "created_at" => :date_range,
        "total_orders" => :number_range
      }
    },
    
    selection: %{
      enabled: true,
      type: :checkbox,  # :checkbox, :radio, :click
      select_all: true,
      preserve_selection: true  # Across pagination
    },
    
    export: %{
      enabled: true,
      formats: [:csv, :excel, :json, :pdf],
      include_selected_only: true,
      custom_filename: "customers_export"
    }
  },
  
  # Column configuration
  columns: %{
    "name" => %{
      title: "Customer Name",
      width: "200px",
      sortable: true,
      filterable: true,
      formatter: :text
    },
    "email" => %{
      title: "Email Address", 
      width: "250px",
      formatter: {:link, "mailto:{{email}}"},
      cell_class: "font-mono"
    },
    "created_at" => %{
      title: "Registration Date",
      width: "150px",
      formatter: {:date, "MMM d, yyyy"},
      align: :center
    },
    "status" => %{
      title: "Status",
      width: "100px",
      formatter: {:badge, %{
        "active" => "success",
        "inactive" => "secondary", 
        "pending" => "warning"
      }}
    },
    "total_orders" => %{
      title: "Total Orders",
      width: "120px",
      formatter: :number,
      align: :right,
      aggregate: :sum  # Show sum in footer
    }
  }
}
```

#### Responsive Table Configuration
```elixir
# Mobile-responsive table behavior
responsive_config = %{
  breakpoints: %{
    mobile: "640px",
    tablet: "768px", 
    desktop: "1024px"
  },
  
  mobile_strategy: :cards,  # :cards, :accordion, :horizontal_scroll
  
  # Column priority for responsive hiding
  column_priority: %{
    "name" => 1,      # Always visible
    "email" => 2,     # Hide on mobile
    "status" => 1,    # Always visible
    "created_at" => 3, # Hide on tablet and below
    "total_orders" => 2
  },
  
  # Card layout for mobile
  card_template: %{
    title: "{{name}}",
    subtitle: "{{email}}",
    body: "Status: {{status}} | Orders: {{total_orders}}",
    footer: "Registered: {{created_at}}"
  }
}
```

#### Advanced Table Features
```elixir
# Advanced interaction patterns
advanced_features = %{
  # Virtual scrolling for large datasets
  virtualization: %{
    enabled: true,
    row_height: 48,
    buffer_size: 10,
    threshold: 1000  # Enable when >1000 rows
  },
  
  # Inline editing
  inline_editing: %{
    enabled: true,
    editable_fields: ["name", "email", "status"],
    validation: %{
      "name" => {:required, :string},
      "email" => {:required, :email}
    },
    save_strategy: :auto  # :auto, :manual, :batch
  },
  
  # Row grouping
  grouping: %{
    enabled: true,
    group_by: "status",
    collapsible: true,
    show_group_summary: true,
    group_actions: ["bulk_update", "export_group"]
  },
  
  # Drag and drop
  drag_drop: %{
    enabled: true,
    reorder_rows: true,
    reorder_columns: true,
    drag_handle: true  # Show drag handle
  }
}
```

## Table Feature Implementation

### 1. Enhanced Sorting
```elixir
# Multi-column sorting with persistence
sorting_config = %{
  # Sort by multiple columns with priority
  multi_column: true,
  max_sort_columns: 3,
  
  # Visual indicators
  sort_icons: %{
    unsorted: "arrows-up-down",
    asc: "arrow-up", 
    desc: "arrow-down"
  },
  
  # Sort persistence
  persistence: %{
    enabled: true,
    storage: :local_storage,  # :local_storage, :session_storage, :server
    key: "table_sort_{{table_id}}"
  },
  
  # Custom sort functions
  custom_sorts: %{
    "status" => fn a, b ->
      status_priority = %{"active" => 1, "pending" => 2, "inactive" => 3}
      Map.get(status_priority, a) <= Map.get(status_priority, b)
    end
  }
}

# Sort indicator component
def render_sort_header(assigns) do
  ~H"""
  <th 
    class={["sortable-header", @sort_class]}
    phx-click="sort_column"
    phx-value-field={@field}
  >
    <div class="sort-header-content">
      <span><%= @title %></span>
      <.icon name={@sort_icon} class="sort-icon" />
      <%= if @sort_priority do %>
        <span class="sort-priority"><%= @sort_priority %></span>
      <% end %>
    </div>
  </th>
  """
end
```

### 2. Advanced Filtering
```elixir
# Column-level filtering with different input types
filtering_system = %{
  # Global search across all visible columns
  global_search: %{
    enabled: true,
    placeholder: "Search across all columns...",
    debounce_ms: 300,
    highlight_matches: true
  },
  
  # Column-specific filters
  column_filters: %{
    # Text filter with autocomplete
    text: %{
      type: :text,
      operators: ["contains", "starts_with", "ends_with", "equals"],
      autocomplete: true,
      case_sensitive: false
    },
    
    # Select filter with multi-select
    select: %{
      type: :select,
      multiple: true,
      options_source: :data,  # :data, :static, :async
      search_within: true
    },
    
    # Date range picker
    date_range: %{
      type: :date_range,
      presets: ["today", "last_7_days", "last_30_days", "this_month"],
      format: "yyyy-MM-dd"
    },
    
    # Number range slider
    number_range: %{
      type: :number_range,
      min: 0,
      max: 10000,
      step: 100,
      display: :slider  # :slider, :input, :both
    }
  },
  
  # Filter persistence and sharing
  persistence: %{
    enabled: true,
    save_as_preset: true,  # Users can save filter combinations
    share_filters: true    # Generate shareable URLs
  }
}
```

### 3. Row Selection and Bulk Operations
```elixir
# Comprehensive selection system
selection_system = %{
  # Selection configuration
  selection: %{
    type: :checkbox,
    position: :start,  # :start, :end
    select_all_pages: true,  # Select across all pages
    max_selections: nil,  # Unlimited
    selection_counter: true
  },
  
  # Bulk operations
  bulk_operations: [
    %{
      name: "export_selected",
      label: "Export Selected", 
      icon: "download",
      formats: [:csv, :excel]
    },
    %{
      name: "bulk_update_status",
      label: "Update Status",
      icon: "edit",
      form: %{
        fields: [
          %{name: "status", type: :select, options: ["active", "inactive", "pending"]}
        ]
      }
    },
    %{
      name: "bulk_delete",
      label: "Delete Selected",
      icon: "trash", 
      danger: true,
      confirmation: "Are you sure you want to delete {{count}} selected items?"
    }
  ],
  
  # Selection persistence across navigation
  persistence: %{
    enabled: true,
    clear_on_filter: false,  # Maintain selections when filtering
    storage: :session_storage
  }
}
```

### 4. Export Functionality
```elixir
# Multi-format export system
export_system = %{
  # Available formats
  formats: %{
    csv: %{
      enabled: true,
      delimiter: ",",
      include_headers: true,
      encoding: "utf-8"
    },
    
    excel: %{
      enabled: true,
      worksheet_name: "Data Export",
      include_formatting: true,
      freeze_headers: true
    },
    
    json: %{
      enabled: true,
      pretty_print: true,
      include_metadata: true
    },
    
    pdf: %{
      enabled: true,
      orientation: :landscape,
      page_size: "A4",
      include_logo: true,
      custom_header: "Data Export - {{date}}"
    }
  },
  
  # Export options
  options: %{
    # What to export
    scope: :visible,  # :visible, :selected, :all, :filtered
    
    # Column selection for export
    column_selection: true,
    
    # Custom formatting for export
    export_formatters: %{
      "created_at" => {:date, "yyyy-MM-dd HH:mm"},
      "total_orders" => :number,
      "status" => :text
    },
    
    # Background processing for large exports
    async_threshold: 10000,  # Async export for >10k rows
    progress_tracking: true,
    email_completion: true
  }
}
```

## Advanced Table Components

### 1. Column Manager
```elixir
# Column visibility and ordering control
def render_column_manager(assigns) do
  ~H"""
  <div class="column-manager" x-data="columnManager()">
    <button x-on:click="open = !open" class="column-manager-toggle">
      <.icon name="adjustments-horizontal" />
      Columns
    </button>
    
    <div x-show="open" class="column-manager-panel">
      <!-- Column visibility checkboxes -->
      <div class="column-visibility">
        <h4>Show/Hide Columns</h4>
        <%= for {field, config} <- @columns do %>
          <label class="checkbox-label">
            <input 
              type="checkbox" 
              checked={Map.get(config, :visible, true)}
              phx-click="toggle_column_visibility"
              phx-value-field={field}
            />
            <%= Map.get(config, :title, field) %>
          </label>
        <% end %>
      </div>
      
      <!-- Column reordering -->
      <div class="column-reorder" phx-hook="ColumnReorder">
        <h4>Column Order</h4>
        <div class="sortable-columns">
          <%= for field <- @column_order do %>
            <div class="sortable-item" data-field={field}>
              <.icon name="grip-vertical" class="drag-handle" />
              <%= get_column_title(field, @columns) %>
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Reset to defaults -->
      <button phx-click="reset_columns" class="btn-secondary">
        Reset to Defaults
      </button>
    </div>
  </div>
  """
end
```

### 2. Smart Table Footer
```elixir
# Comprehensive table footer with summaries and pagination
def render_table_footer(assigns) do
  ~H"""
  <div class="table-footer">
    <!-- Summary statistics -->
    <div class="table-summary">
      <%= if @selection.count > 0 do %>
        <span class="selection-summary">
          <%= @selection.count %> of <%= @total_rows %> selected
        </span>
      <% end %>
      
      <%= for {field, aggregate} <- @column_aggregates do %>
        <span class="column-aggregate">
          <%= get_column_title(field, @columns) %>: 
          <%= format_aggregate_value(aggregate, field) %>
        </span>
      <% end %>
    </div>
    
    <!-- Pagination controls -->
    <div class="table-pagination">
      <div class="pagination-info">
        Showing <%= @page_start %> to <%= @page_end %> of <%= @total_rows %> entries
      </div>
      
      <div class="pagination-controls">
        <select phx-change="change_page_size" class="page-size-select">
          <%= for size <- [10, 25, 50, 100] do %>
            <option value={size} selected={size == @page_size}>
              <%= size %> per page
            </option>
          <% end %>
        </select>
        
        <.pagination_buttons 
          current_page={@current_page}
          total_pages={@total_pages}
          target="table_pagination"
        />
      </div>
    </div>
    
    <!-- Export controls -->
    <%= if @export.enabled do %>
      <div class="export-controls">
        <.dropdown>
          <:trigger>
            <button class="btn-outline">
              <.icon name="download" />
              Export
            </button>
          </:trigger>
          
          <:content>
            <%= for format <- @export.formats do %>
              <button 
                phx-click="export_table" 
                phx-value-format={format}
                class="dropdown-item"
              >
                Export as <%= String.upcase(format) %>
              </button>
            <% end %>
          </:content>
        </.dropdown>
      </div>
    <% end %>
  </div>
  """
end
```

### 3. Responsive Card Layout
```elixir
# Mobile-optimized card layout for table data
def render_responsive_cards(assigns) do
  ~H"""
  <div class="responsive-cards lg:hidden">
    <%= for row <- @data do %>
      <div class="data-card">
        <!-- Card selection checkbox -->
        <%= if @selection.enabled do %>
          <div class="card-selection">
            <input 
              type="checkbox" 
              phx-click="toggle_row_selection"
              phx-value-id={get_row_id(row)}
              checked={row_selected?(row, @selected_rows)}
            />
          </div>
        <% end %>
        
        <!-- Card header with primary info -->
        <div class="card-header">
          <h3 class="card-title">
            <%= render_field_value(row, @card_template.title) %>
          </h3>
          <%= if @card_template.subtitle do %>
            <p class="card-subtitle">
              <%= render_field_value(row, @card_template.subtitle) %>
            </p>
          <% end %>
        </div>
        
        <!-- Card body with additional fields -->
        <div class="card-body">
          <%= for field <- @card_template.fields do %>
            <div class="card-field">
              <span class="field-label">
                <%= get_column_title(field, @columns) %>:
              </span>
              <span class="field-value">
                <%= render_formatted_value(row, field, @columns[field]) %>
              </span>
            </div>
          <% end %>
        </div>
        
        <!-- Card actions -->
        <%= if @row_actions do %>
          <div class="card-actions">
            <%= for action <- @row_actions do %>
              <button 
                phx-click={action.handler}
                phx-value-id={get_row_id(row)}
                class={["btn-sm", action.style]}
              >
                <.icon name={action.icon} />
                <%= action.label %>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
  """
end
```

## Implementation Phases

### Phase 1: Core Table Enhancement (Week 1-3)
- [ ] Enhanced table component with configurable features
- [ ] Multi-column sorting with persistence
- [ ] Basic column filtering (text, select, date)
- [ ] Row selection with bulk operations
- [ ] Responsive design with mobile card layout

### Phase 2: Advanced Features (Week 4-5)
- [ ] Column manager (show/hide, reorder, resize)
- [ ] Advanced filtering (number ranges, search within select)
- [ ] Export functionality (CSV, Excel, JSON, PDF)
- [ ] Virtual scrolling for large datasets
- [ ] Global search with highlighting

### Phase 3: Interactive Features (Week 6-7)
- [ ] Inline editing capabilities
- [ ] Drag and drop (row/column reordering)
- [ ] Row grouping and collapsing
- [ ] Filter presets and sharing
- [ ] Advanced pagination with jump-to-page

### Phase 4: Polish and Performance (Week 8-9)
- [ ] Performance optimization for large datasets
- [ ] Accessibility improvements (keyboard navigation, screen readers)
- [ ] Animation and micro-interactions
- [ ] Comprehensive testing and documentation
- [ ] Theme customization system

## Performance Considerations

### Virtual Scrolling
```elixir
# Handle large datasets efficiently
virtualization_strategy = %{
  # When to enable virtual scrolling
  threshold: 1000,  # Enable for >1000 rows
  
  # Virtual scrolling configuration
  row_height: 48,     # Fixed row height for calculations
  buffer_size: 10,    # Render extra rows above/below viewport
  overscan: 5,        # Additional rows for smooth scrolling
  
  # Performance optimizations
  use_transform: true,    # Use CSS transforms for positioning
  debounce_scroll: 16,    # ~60fps scroll handling
  lazy_load_data: true    # Load data as needed
}
```

### Efficient Filtering and Sorting
```elixir
# Client-side vs server-side processing
processing_strategy = %{
  # Determine where to process based on data size
  client_side_threshold: 5000,  # Use client-side for <5000 rows
  
  # Client-side optimization
  client_side: %{
    debounce_filter: 300,      # Debounce filter input
    memoize_results: true,     # Cache filter/sort results
    use_web_workers: true      # Offload processing to web worker
  },
  
  # Server-side optimization
  server_side: %{
    batch_size: 100,           # Load data in batches
    preload_strategy: :smart,  # Smart preloading based on usage
    cache_results: true        # Server-side result caching
  }
}
```

## Testing Strategy

### Component Tests
```elixir
test "enhanced table renders with all features" do
  config = enhanced_table_config()
  
  html = render_component(EnhancedTable, config: config, data: sample_data())
  
  # Test basic structure
  assert html =~ "selecto-enhanced-table"
  assert html =~ "sortable-header"
  assert html =~ "filterable-column"
  
  # Test feature rendering
  assert html =~ "column-manager"
  assert html =~ "export-controls"
  assert html =~ "bulk-operations"
end

test "sorting functionality works correctly" do
  {:ok, view, _html} = live(conn, "/customers")
  
  # Initial order
  assert first_row_contains(view, "Alice")
  
  # Click sort on name column
  view |> element("th[phx-value-field='name']") |> render_click()
  
  # Should be sorted ascending
  assert first_row_contains(view, "Alice")
  
  # Click again for descending
  view |> element("th[phx-value-field='name']") |> render_click()
  
  assert first_row_contains(view, "Zoe")
end

test "filtering reduces displayed rows" do
  {:ok, view, _html} = live(conn, "/customers")
  
  initial_count = count_table_rows(view)
  
  # Apply name filter
  view
  |> form("form[phx-change='filter_table']")
  |> render_change(%{filters: %{name: "John"}})
  
  filtered_count = count_table_rows(view)
  assert filtered_count < initial_count
end
```

### Performance Tests
```elixir
test "virtual scrolling handles large datasets" do
  large_dataset = generate_test_data(10_000)
  
  config = %{
    virtualization: %{enabled: true, threshold: 1000},
    data: large_dataset
  }
  
  start_time = System.monotonic_time()
  html = render_component(EnhancedTable, config: config)
  end_time = System.monotonic_time()
  
  render_time = System.convert_time_unit(end_time - start_time, :native, :millisecond)
  
  # Should render quickly even with large dataset
  assert render_time < 100  # <100ms
  
  # Should only render visible rows initially
  row_count = html |> Floki.find("tbody tr") |> length()
  assert row_count < 50  # Only visible rows rendered
end
```

## Documentation Requirements

- [ ] Complete API reference for enhanced table configuration
- [ ] Feature configuration guide (sorting, filtering, export, etc.)
- [ ] Responsive design patterns and mobile optimization
- [ ] Performance tuning guide for large datasets  
- [ ] Accessibility implementation guide
- [ ] Theming and customization documentation
- [ ] Migration guide from basic tables

## Success Metrics

- [ ] All major table features implemented (sorting, filtering, export, etc.)
- [ ] Performance maintains <100ms render time for datasets up to 10k rows
- [ ] Mobile-responsive design works across all device sizes
- [ ] Full accessibility compliance (WCAG 2.1 AA)
- [ ] Export functionality supports all major formats
- [ ] Zero breaking changes to existing table implementations
- [ ] Virtual scrolling efficiently handles 100k+ row datasets
- [ ] Comprehensive test coverage including performance tests (>95%)