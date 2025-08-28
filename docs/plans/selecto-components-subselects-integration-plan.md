# SelectoComponents Subselects Integration Plan

## Overview

Integrate Selecto's subselect functionality into SelectoComponents' detail view interface to enable rich, hierarchical data display with related records shown as embedded arrays, cards, or expandable sections without result set denormalization.

## Current State Analysis

### Existing Detail View Limitations
- Detail views show only the primary entity data
- Related records require separate queries or manual joins
- JOIN-based approaches cause result set denormalization
- No built-in UI patterns for one-to-many relationships
- Limited support for nested data visualization

### SelectoComponents Architecture
```elixir
# Current detail view structure
%{
  type: :detail,
  selecto: base_selecto_query,
  fields: ["name", "email", "created_at"],
  actions: [...],
  filters: [...]
}
```

## Architecture Design

### Enhanced Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── detail_view.ex                                # Enhanced detail view component
├── subselect_renderer.ex                         # Subselect-specific rendering
├── related_data/                                  # Related data components
│   ├── embedded_list.ex                          # List view of related records
│   ├── embedded_cards.ex                         # Card-based layout
│   ├── expandable_section.ex                     # Collapsible related data
│   ├── tabbed_sections.ex                        # Tabbed interface for multiple relations
│   └── inline_summary.ex                         # Compact summary display
└── hooks/                                         # JavaScript integration
    ├── subselect_toggle.js                       # Show/hide related data
    ├── lazy_loading.js                           # Load related data on demand
    └── infinite_scroll.js                        # Pagination for large related sets
```

### API Design

#### Basic Subselect Integration
```elixir
# Enhanced detail view with subselects
detail_config = %{
  type: :detail,
  selecto: customer_selecto,
  fields: ["name", "email", "created_at"],
  subselects: [
    %{
      name: "recent_orders",
      fields: ["order[date]", "order[total]", "order[status]"],
      display: :embedded_list,
      limit: 5,
      title: "Recent Orders"
    },
    %{
      name: "addresses",
      fields: ["address[type]", "address[street]", "address[city]"],
      display: :embedded_cards,
      title: "Customer Addresses"
    }
  ]
}
```

#### Advanced Subselect Configuration
```elixir
# Complex subselect with formatting and actions
subselect_config = %{
  name: "order_history",
  fields: [
    "order[order_date]",
    "order[total_amount]", 
    "order[status]",
    "order[item_count]"
  ],
  display: :tabbed_section,
  title: "Order History",
  options: %{
    format: :json_agg,
    order_by: [{"order_date", :desc}],
    limit: 10,
    pagination: true,
    lazy_load: true
  },
  formatting: %{
    "total_amount" => {:currency, :USD},
    "order_date" => {:date, "MMM d, yyyy"},
    "status" => {:badge, %{"completed" => "success", "pending" => "warning"}}
  },
  actions: [
    %{name: "View Order", path: "/orders/:id", icon: "eye"},
    %{name: "Reorder", action: :reorder, icon: "repeat"}
  ]
}
```

#### Interactive Subselect Features
```elixir
# Interactive subselect with drill-down and filtering
interactive_subselect = %{
  name: "sales_analytics",
  fields: ["sale[date]", "sale[amount]", "sale[product_name]"],
  display: :interactive_table,
  title: "Sales History",
  features: %{
    # Enable local filtering on subselect data
    local_filters: [
      %{field: "amount", type: :range, label: "Amount Range"},
      %{field: "product_name", type: :search, label: "Product Search"}
    ],
    # Enable sorting on subselect columns  
    sortable: ["date", "amount", "product_name"],
    # Enable column selection
    column_picker: true,
    # Export subselect data
    export: [:csv, :json],
    # Drill-down to individual records
    drill_down: %{
      path: "/sales/:sale_id",
      fields: ["sale[id]"]
    }
  }
}
```

## Subselect Display Types

### 1. Embedded List
```elixir
# Simple list display for related records
display_config = %{
  type: :embedded_list,
  options: %{
    max_height: "300px",
    scrollable: true,
    empty_message: "No related records found",
    row_template: "{{order_date}} - ${{total_amount}} ({{status}})"
  }
}
```

### 2. Embedded Cards
```elixir
# Card layout for richer data display
display_config = %{
  type: :embedded_cards,
  options: %{
    columns: 2,           # Cards per row
    card_template: %{
      title: "{{product_name}}",
      subtitle: "${{price}}",
      body: "{{description}}",
      footer: "Ordered: {{order_date}}"
    },
    max_cards: 6,         # Show only first 6, with "Show More" link
    card_actions: [
      %{name: "View Details", icon: "eye"},
      %{name: "Reorder", icon: "shopping-cart"}
    ]
  }
}
```

### 3. Expandable Sections
```elixir
# Collapsible sections for space efficiency
display_config = %{
  type: :expandable_section,
  options: %{
    initially_collapsed: true,
    header_template: "{{count}} Orders (Total: ${{total_sum}})",
    summary_fields: ["count(*)", "sum(total_amount)"],  # Summary in header
    expand_icon: "chevron-down",
    collapse_icon: "chevron-up"
  }
}
```

### 4. Tabbed Sections
```elixir
# Multiple related entities in tabs
display_config = %{
  type: :tabbed_sections,
  tabs: [
    %{
      name: "orders",
      title: "Orders",
      badge_field: "count(*)",  # Show count in tab
      fields: ["order[date]", "order[total]", "order[status]"]
    },
    %{
      name: "payments", 
      title: "Payments",
      badge_field: "count(*)",
      fields: ["payment[date]", "payment[amount]", "payment[method]"]
    },
    %{
      name: "support_tickets",
      title: "Support",
      badge_field: "count(*)",
      fields: ["ticket[created_at]", "ticket[subject]", "ticket[status]"]
    }
  ]
}
```

### 5. Inline Summary
```elixir
# Compact summary display
display_config = %{
  type: :inline_summary,
  options: %{
    template: "{{order_count}} orders totaling ${{total_amount}} since {{first_order_date}}",
    aggregates: [
      {:count, "order[id]", as: "order_count"},
      {:sum, "order[total]", as: "total_amount"},
      {:min, "order[date]", as: "first_order_date"}
    ],
    click_to_expand: true,  # Click to show full list
    expand_display: :embedded_list
  }
}
```

## Implementation Phases

### Phase 1: Core Integration (Week 1-3)
- [ ] Extend DetailView component to support subselects
- [ ] Implement basic embedded list display
- [ ] Subselect data fetching and rendering pipeline
- [ ] Integration with existing SelectoComponents architecture

### Phase 2: Display Variants (Week 4-5)
- [ ] Embedded cards display implementation
- [ ] Expandable sections with collapse/expand functionality
- [ ] Tabbed sections for multiple related entities
- [ ] Inline summary display with aggregations

### Phase 3: Interactive Features (Week 6-7)
- [ ] Local filtering on subselect data
- [ ] Sorting and column selection for subselects
- [ ] Drill-down navigation from subselect records
- [ ] Export functionality for subselect data

### Phase 4: Performance & Polish (Week 8-9)
- [ ] Lazy loading for large subselect datasets
- [ ] Pagination within subselect displays
- [ ] Caching strategies for frequently accessed subselects
- [ ] Performance optimization and testing

## Subselect Data Flow

### Data Fetching Pipeline
```elixir
# 1. DetailView component receives enhanced configuration
detail_config_with_subselects = %{
  selecto: main_query,
  subselects: [subselect_configs...]
}

# 2. Main query executed with subselects
enhanced_selecto = main_query
  |> Selecto.subselect(["order[date]", "order[total]"], as: "recent_orders")
  |> Selecto.subselect(["address[type]", "address[street]"], as: "addresses")

# 3. Single query returns main data + subselect arrays
{:ok, results} = Selecto.execute(enhanced_selecto, format: :maps)

# Results structure:
[
  %{
    # Main record fields
    "name" => "John Doe",
    "email" => "john@example.com",
    
    # Subselect arrays
    "recent_orders" => [
      %{"date" => "2023-01-15", "total" => "250.00"},
      %{"date" => "2023-01-10", "total" => "175.50"}
    ],
    "addresses" => [
      %{"type" => "billing", "street" => "123 Main St"},
      %{"type" => "shipping", "street" => "456 Oak Ave"}
    ]
  }
]
```

### Component Rendering Flow
```elixir
# 4. DetailView component processes results
def render_detail_with_subselects(assigns) do
  %{record: record, subselect_configs: configs} = assigns
  
  ~H"""
  <div class="detail-view">
    <!-- Main record fields -->
    <.render_main_fields record={@record} />
    
    <!-- Subselect sections -->
    <%= for config <- @subselect_configs do %>
      <.render_subselect 
        data={Map.get(@record, config.name)} 
        config={config} 
      />
    <% end %>
  </div>
  """
end

# 5. Subselect renderer handles display type
def render_subselect(%{data: data, config: %{display: :embedded_list}} = assigns) do
  ~H"""
  <div class="subselect-section">
    <h3><%= @config.title %></h3>
    <.embedded_list items={@data} config={@config} />
  </div>
  """
end
```

## Advanced Features

### Conditional Subselects
```elixir
# Show subselects based on main record data
conditional_subselects = [
  %{
    name: "order_analytics",
    condition: fn record -> record["order_count"] > 0 end,
    fields: ["order[date]", "order[total]"],
    display: :embedded_list,
    title: "Order History"
  },
  %{
    name: "vip_services", 
    condition: fn record -> record["customer_tier"] == "VIP" end,
    fields: ["service[name]", "service[date_used]"],
    display: :embedded_cards,
    title: "VIP Services Used"
  }
]
```

### Real-time Subselect Updates
```elixir
# LiveView integration for real-time updates
def handle_info({:update_subselect, customer_id, subselect_name}, socket) do
  updated_data = fetch_updated_subselect_data(customer_id, subselect_name)
  
  socket = update(socket, :detail_record, fn record ->
    Map.put(record, subselect_name, updated_data)
  end)
  
  {:noreply, socket}
end

# JavaScript hook for real-time updates
hooks = %{
  "SubselectUpdater" => """
    mounted() {
      this.channel = this.pushEvent("subscribe_subselect", {
        record_id: this.el.dataset.recordId,
        subselect: this.el.dataset.subselectName
      })
    }
  """
}
```

### Subselect Actions and Workflows
```elixir
# Actions that can be performed on subselect items
subselect_actions = [
  %{
    name: "quick_reorder",
    label: "Reorder",
    icon: "shopping-cart",
    handler: {:live_action, :reorder_items},
    bulk_action: true,  # Can be applied to multiple selected items
    confirmation: "Reorder selected items?"
  },
  %{
    name: "view_details",
    label: "View Details", 
    icon: "eye",
    handler: {:navigate, "/orders/{{order_id}}"},
    new_tab: true
  },
  %{
    name: "download_receipt",
    label: "Receipt",
    icon: "download", 
    handler: {:download, "/receipts/{{order_id}}.pdf"},
    condition: fn item -> item["status"] == "completed" end
  }
]
```

## Integration with Existing Features

### SelectoComponents Integration
```elixir
# Enhanced form configuration with subselects
form_config = %{
  type: :detail,
  domain: customer_domain,
  
  # Main record configuration
  fields: ["name", "email", "phone", "created_at"],
  
  # Subselect configurations
  subselects: [
    %{
      name: "orders",
      display: :tabbed_section,
      fields: ["order[date]", "order[total]", "order[status]"],
      title: "Order History"
    },
    %{
      name: "support_tickets",
      display: :expandable_section, 
      fields: ["ticket[subject]", "ticket[status]", "ticket[created_at]"],
      title: "Support History"
    }
  ],
  
  # Global actions
  actions: [...],
  filters: [...]
}
```

### Drill-down Navigation
```elixir
# Seamless navigation from subselects
drill_down_config = %{
  enabled: true,
  target_view: :detail,  # or :aggregate, :custom
  navigation: %{
    # When clicking on an order in subselect
    "orders" => %{
      path: "/orders/:order_id",
      params: %{"order_id" => "{{order[id]}}"},
      type: :modal  # or :page, :drawer
    },
    
    # When clicking on support ticket
    "support_tickets" => %{
      path: "/support/:ticket_id", 
      params: %{"ticket_id" => "{{ticket[id]}}"},
      type: :drawer
    }
  }
}
```

## Performance Optimization

### Lazy Loading Strategy
```elixir
# Load subselects on-demand to improve initial page load
lazy_loading_config = %{
  strategy: :on_expand,  # or :on_scroll, :on_click, :immediate
  preload: ["recent_orders"],  # Always load these subselects
  defer: ["old_orders", "archived_data"],  # Load on user interaction
  cache_duration: {:minutes, 5}  # Cache subselect data
}
```

### Pagination for Large Subselects
```elixir
# Paginate large subselect datasets
pagination_config = %{
  enabled: true,
  page_size: 10,
  pagination_type: :load_more,  # or :numbered, :infinite_scroll
  show_total: true,
  client_side: false  # Server-side pagination for large datasets
}
```

### Caching Strategy
```elixir
# Cache frequently accessed subselect data
cache_config = %{
  enabled: true,
  cache_key: "subselect:{{record_type}}:{{record_id}}:{{subselect_name}}",
  ttl: {:minutes, 10},
  invalidation_events: [
    "order_created",
    "order_updated", 
    "payment_received"
  ]
}
```

## Testing Strategy

### Component Tests
```elixir
test "renders detail view with embedded subselects" do
  config = %{
    type: :detail,
    subselects: [
      %{name: "orders", fields: ["order[date]", "order[total]"], display: :embedded_list}
    ]
  }
  
  html = render_component(DetailView, config: config, record: sample_record)
  
  assert html =~ "Order History"
  assert html =~ "2023-01-15"
  assert html =~ "$250.00"
end

test "handles empty subselects gracefully" do
  record = %{"name" => "John", "orders" => []}
  
  html = render_component(DetailView, record: record, subselects: order_subselect_config)
  
  assert html =~ "No orders found"
  refute html =~ "Order History"  # Section hidden when empty
end
```

### Integration Tests
```elixir
test "subselect drill-down navigation works" do
  {:ok, view, _html} = live(conn, "/customers/123")
  
  # Click on first order in subselect
  view
  |> element("[data-subselect='orders'] [data-row='0']")
  |> render_click()
  
  # Should navigate to order detail
  assert_redirected(view, "/orders/456")
end

test "lazy loading fetches data on expand" do
  {:ok, view, _html} = live(conn, "/customers/123")
  
  # Initially, lazy subselect should not be loaded
  refute has_element?(view, "[data-subselect='archived_orders'] .subselect-data")
  
  # Expand the section
  view
  |> element("[data-subselect='archived_orders'] .expand-toggle")
  |> render_click()
  
  # Should now have loaded data
  assert has_element?(view, "[data-subselect='archived_orders'] .subselect-data")
end
```

## Documentation Requirements

- [ ] Complete API reference for subselect display types
- [ ] Integration guide with existing SelectoComponents forms
- [ ] Performance optimization guide for large subselects
- [ ] Styling and customization documentation
- [ ] Migration guide from separate query approaches

## Success Metrics

- [ ] All major subselect display types implemented and tested
- [ ] Performance improvement over separate query approaches (>30% faster)
- [ ] Zero breaking changes to existing SelectoComponents API
- [ ] Lazy loading reduces initial page load time by >50%
- [ ] Comprehensive test coverage including interactive features (>95%)
- [ ] Clear documentation with practical examples