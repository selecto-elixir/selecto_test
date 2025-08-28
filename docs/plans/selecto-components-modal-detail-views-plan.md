# SelectoComponents Modal Detail Views Plan

## Overview

Add modal detail view functionality to SelectoComponents' aggregate views, allowing users to click a button or row to open a rich detail view modal without navigating away from the current page, maintaining context and improving user experience.

## Current State Analysis

### Existing Aggregate View Limitations
- Aggregate views show only summarized data (counts, sums, averages)
- No easy way to drill down to individual record details
- Navigation to detail pages loses aggregate view context
- Users must use browser back button to return to aggregate view
- No support for quick preview or editing of individual records

### Current SelectoComponents Architecture
```elixir
# Current aggregate view configuration
%{
  type: :aggregate,
  selecto: base_query,
  group_by: ["region", "category"],
  aggregates: [
    {"sales_amount", %{"format" => "sum"}},
    {"order_count", %{"format" => "count"}}
  ],
  fields: ["region", "category", "total_sales", "order_count"]
}
```

## Architecture Design

### Enhanced Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── aggregate_view.ex                              # Enhanced aggregate view component  
├── modal_detail.ex                                # Modal detail view component
├── modal/                                         # Modal-specific components
│   ├── modal_container.ex                        # Modal wrapper with overlay
│   ├── modal_header.ex                           # Modal header with title/close
│   ├── modal_content.ex                          # Scrollable content area
│   ├── modal_actions.ex                          # Action buttons in modal
│   └── modal_navigation.ex                       # Previous/next navigation
├── detail_resolver.ex                             # Resolve detail queries from aggregate context
└── hooks/                                         # JavaScript integration
    ├── modal_manager.js                          # Modal open/close/navigation
    ├── detail_loader.js                          # Async detail data loading
    ├── keyboard_navigation.js                    # ESC to close, arrow keys to navigate
    └── url_state.js                              # URL state management for modals
```

### API Design

#### Basic Modal Detail Configuration
```elixir
# Enhanced aggregate view with modal detail support
aggregate_config = %{
  type: :aggregate,
  selecto: sales_query,
  group_by: ["region", "sales_rep"],
  aggregates: [
    {"total_sales", %{"format" => "sum"}},
    {"order_count", %{"format" => "count"}}
  ],
  
  # Modal detail configuration
  modal_detail: %{
    enabled: true,
    trigger: :button,  # or :row_click, :both
    detail_query: :auto,  # or custom function
    modal_size: :large,  # :small, :medium, :large, :xl, :fullscreen
    title_template: "Sales Details for {{region}} - {{sales_rep}}"
  }
}
```

#### Advanced Modal Configuration
```elixir
# Complex modal with custom detail resolution
modal_config = %{
  enabled: true,
  trigger: :both,  # Button and row click
  button_config: %{
    label: "View Details",
    icon: "eye",
    position: :end,  # :start, :end, :both
    style: :outline  # :primary, :secondary, :outline, :ghost
  },
  
  # Custom detail query resolution
  detail_resolver: fn aggregate_row ->
    # Extract the identifiers from aggregate row to build detail query
    region = Map.get(aggregate_row, "region")
    sales_rep = Map.get(aggregate_row, "sales_rep")
    
    detail_domain
    |> Selecto.configure(connection)
    |> Selecto.filter([
         {"region", region},
         {"sales_rep_name", sales_rep}
       ])
    |> Selecto.select(["customer_name", "order_date", "product", "amount"])
    |> Selecto.order_by([{"order_date", :desc}])
  end,
  
  # Modal presentation options
  modal_options: %{
    size: :large,
    closable: true,
    backdrop_close: true,
    keyboard_navigation: true,
    animation: :slide_up,  # :fade, :slide_up, :slide_right, :zoom
    max_height: "80vh",
    position: :center  # :center, :top, :bottom
  },
  
  # Header configuration
  header: %{
    title_template: "{{order_count}} Orders - {{region}}",
    subtitle_template: "Sales Rep: {{sales_rep}} | Total: ${{total_sales}}",
    show_close_button: true,
    custom_actions: [
      %{label: "Export", icon: "download", action: :export_csv},
      %{label: "Email Report", icon: "mail", action: :send_report}
    ]
  }
}
```

#### Modal Navigation and State Management
```elixir
# Multi-record navigation within modal
navigation_config = %{
  enabled: true,
  
  # Navigate between aggregate rows without closing modal
  navigation: %{
    enabled: true,
    show_counter: true,  # "2 of 25" 
    keyboard_shortcuts: true,  # Arrow keys, Page Up/Down
    preload_adjacent: true,  # Preload next/prev for smooth navigation
    wrap_around: false  # Don't wrap from last to first
  },
  
  # URL state management
  url_state: %{
    enabled: true,
    param_name: "detail_id",
    update_url: true,  # Update browser URL when modal opens
    preserve_history: true  # Enable browser back/forward
  },
  
  # Deep linking support
  deep_linking: %{
    enabled: true,
    auto_open: true,  # Auto-open modal if URL contains detail_id
    fallback_behavior: :redirect  # :redirect, :show_message, :ignore
  }
}
```

## Modal Detail Display Types

### 1. Standard Detail View
```elixir
# Regular detail view rendered in modal
detail_display = %{
  type: :detail,
  fields: ["customer_name", "email", "phone", "order_date", "total_amount"],
  layout: :vertical,  # or :horizontal, :grid
  field_formatting: %{
    "total_amount" => {:currency, :USD},
    "order_date" => {:date, "MMM d, yyyy"},
    "email" => {:link, "mailto:{{email}}"}
  }
}
```

### 2. Tabbed Detail View
```elixir
# Multiple sections in tabs
tabbed_detail = %{
  type: :tabbed_detail,
  tabs: [
    %{
      name: "overview",
      title: "Overview", 
      fields: ["customer_name", "email", "total_orders", "total_spent"]
    },
    %{
      name: "recent_orders",
      title: "Recent Orders",
      type: :list,
      fields: ["order_date", "products", "amount", "status"]
    },
    %{
      name: "analytics",
      title: "Analytics",
      type: :charts,
      charts: [
        %{type: :line, data: "monthly_sales", title: "Sales Trend"},
        %{type: :pie, data: "product_distribution", title: "Product Mix"}
      ]
    }
  ]
}
```

### 3. Related Records View
```elixir
# Show individual records that make up the aggregate
related_records = %{
  type: :related_records,
  title: "Individual Orders",
  display: :table,
  fields: ["order_id", "customer", "date", "amount", "status"],
  options: %{
    sortable: true,
    filterable: true,
    paginated: true,
    page_size: 10,
    actions: [
      %{name: "View Order", path: "/orders/:order_id", icon: "eye"},
      %{name: "Edit", action: :edit_order, icon: "pencil"}
    ]
  }
}
```

### 4. Summary with Breakdown
```elixir
# Aggregate summary with detailed breakdown
summary_breakdown = %{
  type: :summary_breakdown,
  summary: %{
    metrics: [
      %{label: "Total Sales", value: "{{total_sales}}", format: :currency},
      %{label: "Order Count", value: "{{order_count}}", format: :number},
      %{label: "Avg Order Value", value: "{{avg_order_value}}", format: :currency}
    ]
  },
  breakdown: %{
    type: :charts,
    charts: [
      %{
        type: :bar,
        title: "Sales by Product Category", 
        data_source: :subquery,
        query: product_breakdown_query
      },
      %{
        type: :timeline,
        title: "Sales Timeline",
        data_source: :subquery, 
        query: timeline_query
      }
    ]
  }
}
```

## Implementation Phases

### Phase 1: Core Modal Infrastructure (Week 1-2)
- [ ] Modal container component with overlay and positioning
- [ ] Basic modal detail view integration with aggregate views
- [ ] Button trigger configuration and row click handlers
- [ ] Simple detail query resolution from aggregate context

### Phase 2: Advanced Modal Features (Week 3-4)
- [ ] Modal navigation (previous/next record)
- [ ] Keyboard navigation and shortcuts (ESC, arrows)
- [ ] URL state management and deep linking
- [ ] Custom modal sizes and positioning options

### Phase 3: Rich Detail Displays (Week 5-6)
- [ ] Tabbed detail views within modals
- [ ] Related records display with pagination
- [ ] Summary with breakdown visualizations
- [ ] Charts and analytics integration in modals

### Phase 4: Polish and Performance (Week 7-8)
- [ ] Smooth animations and transitions
- [ ] Preloading and caching strategies
- [ ] Mobile-responsive modal design
- [ ] Comprehensive testing and documentation

## Detail Query Resolution

### Automatic Resolution
```elixir
# Automatic detail resolution based on aggregate GROUP BY
def resolve_detail_query(aggregate_config, selected_row) do
  group_by_fields = aggregate_config.group_by
  
  # Extract values from selected row for each GROUP BY field
  filters = Enum.map(group_by_fields, fn field ->
    value = Map.get(selected_row, field)
    {field, value}
  end)
  
  # Build detail query with same base as aggregate but with filters
  aggregate_config.selecto
  |> Selecto.filter(filters)
  |> Selecto.select(determine_detail_fields(aggregate_config))
  |> Selecto.order_by([{"created_at", :desc}])  # Default ordering
end
```

### Custom Resolution Functions
```elixir
# Advanced resolution with business logic
custom_resolver = fn aggregate_row ->
  case aggregate_row do
    %{"region" => "North America", "category" => category} ->
      # Special handling for North America
      build_na_detail_query(category)
      
    %{"region" => region, "sales_rep" => rep} when rep != nil ->
      # Sales rep specific details
      build_rep_detail_query(region, rep)
      
    _ ->
      # Default detail query
      build_default_detail_query(aggregate_row)
  end
end
```

### Context-Aware Field Selection
```elixir
# Smart field selection based on aggregate context
def determine_detail_fields(aggregate_config) do
  base_fields = ["id", "created_at", "updated_at"]
  
  # Add fields based on what was aggregated
  aggregate_fields = aggregate_config.aggregates
    |> Enum.map(fn {field, _config} -> field end)
    |> Enum.uniq()
    
  # Add GROUP BY fields for context
  grouping_fields = aggregate_config.group_by
  
  # Combine and deduplicate
  (base_fields ++ aggregate_fields ++ grouping_fields)
  |> Enum.uniq()
  |> Enum.reject(&(&1 in ["count(*)", "sum(*)"]))  # Remove aggregate functions
end
```

## Modal User Experience

### Loading States and Performance
```elixir
# Progressive loading for better UX
loading_strategy = %{
  # Show modal immediately with loading spinner
  immediate_show: true,
  
  # Progressive content loading
  progressive_loading: %{
    # Load basic info first
    priority_1: ["name", "email", "created_at"],
    # Load detailed info second  
    priority_2: ["description", "notes", "metadata"],
    # Load heavy computation last
    priority_3: ["analytics", "charts", "related_records"]
  },
  
  # Skeleton loading for known layouts
  skeleton_loading: true,
  
  # Preload adjacent records for navigation
  preload_adjacent: %{
    enabled: true,
    count: 2,  # Preload 2 records on each side
    background: true  # Load in background
  }
}
```

### Responsive Design
```elixir
# Modal behavior across device sizes
responsive_config = %{
  desktop: %{
    size: :large,
    position: :center,
    max_width: "800px",
    animation: :fade
  },
  tablet: %{
    size: :medium,
    position: :center,
    max_width: "90vw",
    animation: :slide_up
  },
  mobile: %{
    size: :fullscreen,  # Full screen on mobile
    position: :bottom,
    animation: :slide_up,
    header_sticky: true,  # Sticky header on scroll
    swipe_to_close: true  # Swipe down to close
  }
}
```

### Accessibility Features
```elixir
# Accessibility configuration
a11y_config = %{
  # ARIA attributes
  aria: %{
    role: "dialog",
    label_template: "Details for {{title}}",
    described_by: "modal-content"
  },
  
  # Keyboard navigation
  keyboard: %{
    trap_focus: true,  # Keep focus within modal
    initial_focus: ".modal-close",  # First focusable element
    return_focus: true,  # Return focus to trigger element
    shortcuts: %{
      "Escape" => :close,
      "ArrowLeft" => :previous_record,
      "ArrowRight" => :next_record
    }
  },
  
  # Screen reader support
  screen_reader: %{
    announce_open: true,
    announce_navigation: true,
    live_region: "polite"
  }
}
```

## Integration with Existing Features

### Aggregate View Enhancement
```elixir
# Enhanced aggregate table with modal buttons
def render_aggregate_row(assigns) do
  ~H"""
  <tr class="aggregate-row" data-modal-trigger={@modal_config.trigger}>
    <%= for field <- @fields do %>
      <td><%= render_field_value(@row, field) %></td>
    <% end %>
    
    <!-- Modal trigger button -->
    <%= if @modal_config.enabled do %>
      <td>
        <.button 
          phx-click="open_modal_detail" 
          phx-value-row-id={@row.id}
          class="btn-sm"
        >
          <%= @modal_config.button_config.label %>
          <.icon name={@modal_config.button_config.icon} />
        </.button>
      </td>
    <% end %>
  </tr>
  """
end
```

### LiveView Event Handling
```elixir
# LiveView event handlers for modal functionality
def handle_event("open_modal_detail", %{"row-id" => row_id}, socket) do
  # Resolve detail query for the selected row
  aggregate_row = find_aggregate_row(socket.assigns.results, row_id)
  detail_query = resolve_detail_query(socket.assigns.config, aggregate_row)
  
  # Execute detail query
  case Selecto.execute(detail_query) do
    {:ok, {rows, columns, _aliases}} ->
      detail_data = format_detail_data(rows, columns)
      
      socket = socket
        |> assign(:modal_open, true)
        |> assign(:modal_detail_data, detail_data)
        |> assign(:current_row_id, row_id)
        
      {:noreply, socket}
      
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed to load details: #{reason}")}
  end
end

def handle_event("close_modal_detail", _params, socket) do
  socket = socket
    |> assign(:modal_open, false)
    |> assign(:modal_detail_data, nil)
    |> assign(:current_row_id, nil)
    
  {:noreply, socket}
end

def handle_event("navigate_modal", %{"direction" => direction}, socket) do
  current_id = socket.assigns.current_row_id
  new_id = get_adjacent_row_id(socket.assigns.results, current_id, direction)
  
  # Reuse open_modal_detail logic
  handle_event("open_modal_detail", %{"row-id" => new_id}, socket)
end
```

## Performance Optimizations

### Caching Strategy
```elixir
# Multi-level caching for modal details
cache_strategy = %{
  # Cache detail queries by row identifier
  query_cache: %{
    enabled: true,
    ttl: {:minutes, 5},
    key_template: "modal_detail:{{aggregate_type}}:{{row_hash}}"
  },
  
  # Cache resolved detail data
  data_cache: %{
    enabled: true,
    ttl: {:minutes, 10},
    max_entries: 100,  # LRU cache
    invalidation_events: ["record_updated", "record_deleted"]
  },
  
  # Browser-side caching for navigation
  client_cache: %{
    enabled: true,
    storage: :session_storage,
    max_size_mb: 5
  }
}
```

### Preloading and Background Loading
```elixir
# Intelligent preloading strategies
preload_strategy = %{
  # Preload details for visible rows
  visible_rows: %{
    enabled: true,
    trigger: :on_scroll,  # or :on_hover, :immediate
    priority: :background  # Don't block UI
  },
  
  # Preload adjacent records for navigation
  adjacent_records: %{
    enabled: true,
    count: 3,  # Preload 3 records in each direction
    trigger: :on_modal_open
  },
  
  # Smart preloading based on user behavior
  predictive: %{
    enabled: true,
    ml_model: :simple_pattern,  # Track user navigation patterns
    confidence_threshold: 0.7
  }
}
```

## Testing Strategy

### Component Tests
```elixir
test "renders modal trigger button in aggregate view" do
  config = %{
    type: :aggregate,
    modal_detail: %{enabled: true, trigger: :button}
  }
  
  html = render_component(AggregateView, config: config, results: sample_data)
  
  assert html =~ "data-modal-trigger"
  assert html =~ "open_modal_detail"
end

test "modal opens with correct detail data" do
  {:ok, view, _html} = live(conn, "/analytics")
  
  # Click modal trigger button
  view
  |> element("[data-testid='modal-trigger-0']")
  |> render_click()
  
  # Modal should be open with detail data
  assert has_element?(view, "[data-testid='modal-detail']")
  assert has_element?(view, ".modal-content")
end

test "modal navigation works correctly" do
  {:ok, view, _html} = live(conn, "/analytics")
  
  # Open modal for first row
  view |> element("[data-testid='modal-trigger-0']") |> render_click()
  
  # Navigate to next record
  view |> element("[data-testid='modal-next']") |> render_click()
  
  # Should show different data
  assert has_element?(view, "[data-row-id='1']")
end
```

### Integration Tests
```elixir
test "modal maintains URL state" do
  {:ok, view, _html} = live(conn, "/analytics")
  
  view |> element("[data-testid='modal-trigger-0']") |> render_click()
  
  # URL should be updated
  assert_patch(view, "/analytics?detail_id=0")
  
  # Direct navigation should open modal
  {:ok, view2, _html} = live(conn, "/analytics?detail_id=1") 
  assert has_element?(view2, "[data-testid='modal-detail']")
end

test "modal works on mobile devices" do
  conn = conn |> put_req_header("user-agent", mobile_user_agent)
  
  {:ok, view, html} = live(conn, "/analytics")
  
  view |> element("[data-testid='modal-trigger-0']") |> render_click()
  
  # Should use fullscreen modal on mobile
  assert has_element?(view, ".modal-fullscreen")
  assert has_element?(view, "[data-swipe-close]")
end
```

## Documentation Requirements

- [ ] Complete API reference for modal detail configuration
- [ ] Integration guide with existing aggregate views
- [ ] Customization examples for different modal layouts
- [ ] Performance optimization guide for large datasets
- [ ] Accessibility best practices for modal implementations
- [ ] Mobile-responsive design patterns and examples

## Success Metrics

- [ ] Modal functionality integrated into all aggregate view types
- [ ] Smooth user experience with <200ms modal open time
- [ ] Full keyboard and screen reader accessibility compliance
- [ ] Mobile-responsive design working across all device sizes
- [ ] URL state management for deep linking and browser navigation
- [ ] Performance maintains <100ms navigation between modal records
- [ ] Zero breaking changes to existing SelectoComponents API
- [ ] Comprehensive test coverage including accessibility tests (>95%)