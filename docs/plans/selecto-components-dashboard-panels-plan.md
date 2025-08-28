# SelectoComponents Dashboard Panels Plan

## Overview

Create embeddable HTML Custom Elements that render SelectoComponents views (aggregate, detail, or graph) from magic URLs, enabling dashboard panels that can be integrated into any website, application, or CMS without requiring Elixir/Phoenix knowledge.

## Architecture Design

### Core Component Structure
```
vendor/selecto_components/lib/selecto_components/
├── dashboard_panels/                             # Dashboard panel system
│   ├── panel_registry.ex                        # Panel configuration registry  
│   ├── panel_renderer.ex                        # Server-side panel rendering
│   ├── panel_api.ex                             # REST API for panel data
│   ├── panel_auth.ex                            # Authentication and authorization
│   └── panel_cache.ex                           # Panel data caching
├── web_components/                               # Web Component generation
│   ├── custom_element_builder.ex                # HTML Custom Element builder
│   ├── javascript_generator.ex                  # Generate Custom Element JS
│   ├── style_injector.ex                        # CSS injection for panels
│   └── iframe_renderer.ex                       # Secure iframe rendering
├── embed_api/                                    # Embedding API
│   ├── magic_url_generator.ex                   # Generate magic URLs
│   ├── url_parser.ex                            # Parse configuration from URLs
│   ├── embed_controller.ex                      # Handle embed requests
│   └── cors_handler.ex                          # CORS configuration
└── assets/                                       # Generated assets
    ├── dashboard-panel.js                        # Custom Element implementation
    ├── dashboard-panel.css                       # Panel styling
    └── themes/                                   # Theme-specific assets
```

### API Design

#### Magic URL Structure
```
# Base magic URL format
https://your-selecto-app.com/embed/panel/{panel_id}?{configuration}

# Examples of magic URLs:

# Aggregate view panel
https://app.com/embed/panel/sales-summary?
  view=aggregate&
  group_by=region,sales_rep&
  aggregates=sum:revenue,count:orders&
  filters=date_range:2023-01-01,2023-12-31&
  theme=corporate&
  title=Sales%20Summary

# Detail view panel  
https://app.com/embed/panel/customer-details?
  view=detail&
  record_id=12345&
  fields=name,email,total_orders,last_purchase&
  theme=minimal&
  title=Customer%20Profile

# Graph view panel
https://app.com/embed/panel/revenue-trend?
  view=graph&
  chart_type=line&
  x_axis=month&
  y_axis=revenue&
  group_by=region&
  date_range=last_12_months&
  theme=dark&
  title=Revenue%20Trends
```

#### HTML Custom Element Usage
```html
<!-- Simple panel embedding -->
<selecto-dashboard-panel 
  src="https://app.com/embed/panel/sales-summary?view=aggregate&group_by=region"
  width="800px" 
  height="400px"
  theme="corporate">
</selecto-dashboard-panel>

<!-- Advanced panel with custom configuration -->
<selecto-dashboard-panel 
  src="https://app.com/embed/panel/custom"
  config='{
    "view": "aggregate",
    "domain": "sales",
    "group_by": ["region", "product_category"],
    "aggregates": [
      {"field": "revenue", "function": "sum"},
      {"field": "orders", "function": "count"}
    ],
    "filters": [
      {"field": "date", "operator": "between", "value": ["2023-01-01", "2023-12-31"]}
    ],
    "styling": {
      "theme": "corporate",
      "colors": {"primary": "#3b82f6"},
      "fonts": {"family": "Inter, sans-serif"}
    }
  }'
  auto-refresh="30000"
  interactive="true">
</selecto-dashboard-panel>

<!-- Panel with authentication -->
<selecto-dashboard-panel 
  src="https://app.com/embed/panel/protected-data"
  api-key="your-api-key"
  jwt-token="your-jwt-token"
  sandbox="true">
</selecto-dashboard-panel>
```

#### Panel Configuration Schema
```elixir
# Comprehensive panel configuration
panel_config = %{
  # Panel identification
  id: "sales_dashboard_panel",
  name: "Sales Dashboard",
  description: "Real-time sales performance metrics",
  version: "1.0.0",
  
  # View configuration
  view: %{
    type: :aggregate,  # :aggregate, :detail, :graph
    
    # Data source
    domain: "sales_domain",
    
    # View-specific configuration
    aggregate: %{
      group_by: ["region", "sales_rep", "product_category"],
      aggregates: [
        %{field: "revenue", function: "sum", format: "currency"},
        %{field: "orders", function: "count"},
        %{field: "avg_order_value", function: "avg", format: "currency"}
      ],
      
      # Sorting and limits
      order_by: [{"revenue", :desc}],
      limit: 100
    }
  },
  
  # Filtering configuration
  filters: [
    %{
      field: "date_range",
      type: :date_range,
      default: "last_30_days",
      required: false,
      user_configurable: true
    },
    %{
      field: "region", 
      type: :multi_select,
      options: ["North America", "Europe", "Asia Pacific"],
      default: ["North America"],
      user_configurable: true
    },
    %{
      field: "status",
      type: :select,
      options: ["active", "completed", "cancelled"],
      default: "active",
      user_configurable: false  # Fixed filter
    }
  ],
  
  # Presentation configuration
  presentation: %{
    title: "Sales Performance Dashboard",
    description: "Real-time sales metrics and trends",
    
    # Layout options
    layout: %{
      type: :responsive,  # :responsive, :fixed, :fluid
      width: "100%",
      height: "400px",
      min_width: "300px",
      min_height: "200px"
    },
    
    # Styling
    styling: %{
      theme: "corporate",
      custom_css: nil,
      color_overrides: %{
        primary: "#3b82f6",
        secondary: "#6b7280"
      },
      
      # Component-specific styling
      table: %{
        striped_rows: true,
        hover_effects: true,
        compact_mode: false
      }
    },
    
    # Interactivity
    interactivity: %{
      sortable: true,
      filterable: true,
      exportable: true,
      drill_down: true,
      
      # User controls
      show_filters: true,
      show_export_button: true,
      show_refresh_button: true
    }
  },
  
  # Data refresh configuration
  refresh: %{
    auto_refresh: true,
    interval: 30000,  # 30 seconds
    on_focus: true,   # Refresh when panel gains focus
    manual_refresh: true
  },
  
  # Security and access control
  security: %{
    authentication: %{
      required: true,
      methods: ["api_key", "jwt", "oauth"],
      api_key_header: "X-API-Key"
    },
    
    authorization: %{
      required_permissions: ["read:sales_data"],
      row_level_security: true,
      field_level_security: ["sensitive_customer_data"]
    },
    
    # Embedding restrictions
    embedding: %{
      allowed_origins: ["https://company.com", "https://app.company.com"],
      sandbox_mode: true,
      iframe_options: %{
        allow_scripts: true,
        allow_same_origin: false,
        allow_forms: false
      }
    }
  },
  
  # Performance and caching
  performance: %{
    cache_duration: 300,  # 5 minutes
    max_results: 10000,
    timeout: 30000,       # 30 second query timeout
    
    # Progressive loading
    progressive_loading: %{
      enabled: true,
      initial_load_size: 50,
      load_more_size: 100
    }
  },
  
  # Error handling and fallbacks
  error_handling: %{
    show_errors: false,  # Hide technical errors from embedded users
    fallback_message: "Data temporarily unavailable",
    retry_attempts: 3,
    retry_delay: 5000
  }
}
```

## Implementation Architecture

### 1. Magic URL Generation and Parsing
```elixir
defmodule SelectoComponents.MagicUrlGenerator do
  @moduledoc """
  Generate and parse magic URLs for dashboard panels.
  """
  
  def generate_magic_url(panel_config, base_url \\ nil) do
    base = base_url || get_base_url()
    panel_id = panel_config.id
    
    # Encode configuration as URL parameters
    query_params = encode_panel_config(panel_config)
    
    # Generate signed URL for security
    signature = sign_url_params(query_params)
    
    "#{base}/embed/panel/#{panel_id}?#{query_params}&signature=#{signature}"
  end
  
  def parse_magic_url(url) do
    with {:ok, %URI{path: path, query: query}} <- URI.new(url),
         {:ok, panel_id} <- extract_panel_id(path),
         {:ok, params} <- URI.decode_query(query),
         {:ok, signature} <- Map.fetch(params, "signature"),
         :ok <- verify_signature(params, signature),
         {:ok, config} <- decode_panel_config(params) do
      {:ok, %{panel_id: panel_id, config: config}}
    else
      error -> {:error, "Invalid magic URL: #{inspect(error)}"}
    end
  end
  
  defp encode_panel_config(config) do
    config
    |> Map.take([:view, :filters, :presentation, :refresh])
    |> Jason.encode!()
    |> Base.url_encode64()
  end
  
  defp sign_url_params(params) do
    secret_key = Application.get_env(:selecto_components, :url_signing_key)
    :crypto.mac(:hmac, :sha256, secret_key, params)
    |> Base.url_encode64()
  end
end
```

### 2. HTML Custom Element Implementation
```javascript
// dashboard-panel.js - Custom Element implementation
class SelectoDashboardPanel extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this.config = null;
    this.refreshInterval = null;
  }
  
  static get observedAttributes() {
    return ['src', 'config', 'theme', 'auto-refresh', 'interactive', 'api-key'];
  }
  
  connectedCallback() {
    this.initialize();
  }
  
  disconnectedCallback() {
    this.cleanup();
  }
  
  attributeChangedCallback(name, oldValue, newValue) {
    if (oldValue !== newValue) {
      this.handleAttributeChange(name, newValue);
    }
  }
  
  async initialize() {
    try {
      // Parse configuration from attributes
      this.config = await this.parseConfiguration();
      
      // Set up styling
      await this.injectStyles();
      
      // Create container structure
      this.createContainer();
      
      // Load initial data
      await this.loadPanelData();
      
      // Set up auto-refresh if enabled
      this.setupAutoRefresh();
      
      // Set up event listeners
      this.setupEventListeners();
      
    } catch (error) {
      this.showError('Failed to initialize dashboard panel', error);
    }
  }
  
  async parseConfiguration() {
    const src = this.getAttribute('src');
    const configAttr = this.getAttribute('config');
    
    if (configAttr) {
      // Configuration provided directly as attribute
      return JSON.parse(configAttr);
    } else if (src) {
      // Parse configuration from magic URL
      const response = await fetch(`${src}&format=config`, {
        headers: this.getAuthHeaders()
      });
      return await response.json();
    } else {
      throw new Error('Either src or config attribute must be provided');
    }
  }
  
  async injectStyles() {
    const theme = this.getAttribute('theme') || this.config.presentation?.styling?.theme || 'default';
    
    // Load theme-specific CSS
    const styleUrl = `${this.getBaseUrl()}/embed/assets/themes/${theme}.css`;
    const response = await fetch(styleUrl);
    const css = await response.text();
    
    // Create style element
    const style = document.createElement('style');
    style.textContent = css;
    this.shadowRoot.appendChild(style);
  }
  
  createContainer() {
    const container = document.createElement('div');
    container.className = 'selecto-dashboard-panel';
    container.innerHTML = `
      <div class="panel-header" style="display: ${this.config.presentation?.show_header !== false ? 'block' : 'none'}">
        <h3 class="panel-title">${this.config.presentation?.title || 'Dashboard Panel'}</h3>
        <div class="panel-controls">
          <button class="refresh-btn" title="Refresh">↻</button>
          <button class="export-btn" title="Export" style="display: ${this.config.presentation?.interactivity?.exportable ? 'block' : 'none'}">↓</button>
          <button class="fullscreen-btn" title="Fullscreen">⛶</button>
        </div>
      </div>
      
      <div class="panel-filters" style="display: ${this.config.presentation?.interactivity?.show_filters ? 'block' : 'none'}">
        <!-- Dynamic filter controls will be inserted here -->
      </div>
      
      <div class="panel-content">
        <div class="loading-spinner">Loading...</div>
      </div>
      
      <div class="panel-footer">
        <span class="last-updated">Last updated: <span class="timestamp">--</span></span>
        <span class="record-count">Records: <span class="count">--</span></span>
      </div>
    `;
    
    this.shadowRoot.appendChild(container);
  }
  
  async loadPanelData() {
    const contentEl = this.shadowRoot.querySelector('.panel-content');
    const src = this.getAttribute('src');
    
    try {
      // Show loading state
      contentEl.innerHTML = '<div class="loading-spinner">Loading...</div>';
      
      // Fetch panel data
      const response = await fetch(`${src}&format=html`, {
        headers: {
          ...this.getAuthHeaders(),
          'Accept': 'text/html'
        }
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const html = await response.text();
      
      // Update content
      contentEl.innerHTML = html;
      
      // Update timestamp
      this.updateTimestamp();
      
      // Set up interactive features
      this.setupInteractivity();
      
    } catch (error) {
      this.showError('Failed to load panel data', error);
    }
  }
  
  setupAutoRefresh() {
    const autoRefresh = this.getAttribute('auto-refresh');
    if (autoRefresh && parseInt(autoRefresh) > 0) {
      this.refreshInterval = setInterval(() => {
        this.loadPanelData();
      }, parseInt(autoRefresh));
    }
  }
  
  setupInteractivity() {
    // Set up sorting
    if (this.config.presentation?.interactivity?.sortable) {
      this.setupSorting();
    }
    
    // Set up filtering  
    if (this.config.presentation?.interactivity?.filterable) {
      this.setupFiltering();
    }
    
    // Set up drill-down
    if (this.config.presentation?.interactivity?.drill_down) {
      this.setupDrillDown();
    }
  }
  
  setupEventListeners() {
    // Refresh button
    this.shadowRoot.querySelector('.refresh-btn')?.addEventListener('click', () => {
      this.loadPanelData();
    });
    
    // Export button
    this.shadowRoot.querySelector('.export-btn')?.addEventListener('click', () => {
      this.exportData();
    });
    
    // Fullscreen button
    this.shadowRoot.querySelector('.fullscreen-btn')?.addEventListener('click', () => {
      this.toggleFullscreen();
    });
  }
  
  getAuthHeaders() {
    const headers = {};
    
    const apiKey = this.getAttribute('api-key');
    if (apiKey) {
      headers['X-API-Key'] = apiKey;
    }
    
    const jwtToken = this.getAttribute('jwt-token');
    if (jwtToken) {
      headers['Authorization'] = `Bearer ${jwtToken}`;
    }
    
    return headers;
  }
  
  showError(message, error) {
    const contentEl = this.shadowRoot.querySelector('.panel-content');
    contentEl.innerHTML = `
      <div class="error-state">
        <div class="error-icon">⚠️</div>
        <div class="error-message">${message}</div>
        ${process.env.NODE_ENV === 'development' ? `<div class="error-details">${error?.message}</div>` : ''}
        <button class="retry-btn">Retry</button>
      </div>
    `;
    
    contentEl.querySelector('.retry-btn')?.addEventListener('click', () => {
      this.loadPanelData();
    });
  }
  
  cleanup() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }
  }
}

// Register the custom element
customElements.define('selecto-dashboard-panel', SelectoDashboardPanel);

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SelectoDashboardPanel;
}
```

### 3. Server-Side Panel Rendering
```elixir
defmodule SelectoComponents.EmbedController do
  use Phoenix.Controller
  
  def render_panel(conn, %{"panel_id" => panel_id} = params) do
    with {:ok, config} <- parse_panel_config(params),
         {:ok, _user} <- authenticate_request(conn, config),
         :ok <- authorize_request(conn, config),
         {:ok, panel_data} <- fetch_panel_data(config) do
      
      case get_format(params) do
        "html" -> render_html_panel(conn, panel_data, config)
        "json" -> render_json_panel(conn, panel_data, config)  
        "config" -> render_panel_config(conn, config)
        _ -> render_html_panel(conn, panel_data, config)
      end
    else
      {:error, :authentication_required} ->
        conn |> put_status(401) |> json(%{error: "Authentication required"})
        
      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Unauthorized"})
        
      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end
  
  defp render_html_panel(conn, panel_data, config) do
    case config.view.type do
      :aggregate -> render_aggregate_panel(conn, panel_data, config)
      :detail -> render_detail_panel(conn, panel_data, config)
      :graph -> render_graph_panel(conn, panel_data, config)
    end
  end
  
  defp render_aggregate_panel(conn, panel_data, config) do
    html = SelectoComponents.AggregateView.render(%{
      data: panel_data.results,
      config: config.view.aggregate,
      styling: config.presentation.styling,
      interactivity: config.presentation.interactivity
    })
    
    conn
    |> put_resp_header("content-type", "text/html")
    |> put_resp_header("x-panel-version", config.version)
    |> send_resp(200, html)
  end
  
  defp fetch_panel_data(config) do
    # Check cache first
    cache_key = generate_cache_key(config)
    
    case SelectoComponents.PanelCache.get(cache_key) do
      {:ok, cached_data} -> {:ok, cached_data}
      :miss -> fetch_and_cache_panel_data(config, cache_key)
    end
  end
  
  defp fetch_and_cache_panel_data(config, cache_key) do
    with {:ok, selecto_query} <- build_selecto_query(config),
         {:ok, results} <- Selecto.execute(selecto_query) do
      
      panel_data = %{
        results: results,
        generated_at: DateTime.utc_now(),
        config_hash: :crypto.hash(:sha256, Jason.encode!(config))
      }
      
      # Cache the results
      SelectoComponents.PanelCache.put(cache_key, panel_data, config.performance.cache_duration)
      
      {:ok, panel_data}
    end
  end
end
```

### 4. Dashboard Panel Builder Interface
```elixir
# Interactive builder for creating dashboard panels
panel_builder_config = %{
  # Builder interface sections
  sections: [
    %{
      name: "data_source",
      title: "Data Source",
      description: "Configure your data source and query",
      
      fields: [
        %{
          name: "domain",
          type: :domain_selector,
          required: true,
          description: "Select the data domain to query"
        },
        
        %{
          name: "view_type",
          type: :radio_group,
          options: [
            %{value: "aggregate", label: "Aggregate View", description: "Summarized data with grouping"},
            %{value: "detail", label: "Detail View", description: "Individual record details"},
            %{value: "graph", label: "Graph View", description: "Charts and visualizations"}
          ],
          default: "aggregate"
        }
      ]
    },
    
    %{
      name: "visualization",
      title: "Visualization",
      description: "Configure how your data will be displayed",
      
      conditional_fields: %{
        "aggregate" => [
          %{name: "group_by", type: :multi_field_selector, label: "Group By Fields"},
          %{name: "aggregates", type: :aggregate_builder, label: "Aggregations"}
        ],
        
        "detail" => [
          %{name: "fields", type: :field_selector, label: "Display Fields"},
          %{name: "record_selector", type: :record_selector, label: "Record Selection"}
        ],
        
        "graph" => [
          %{name: "chart_type", type: :chart_selector, label: "Chart Type"},
          %{name: "x_axis", type: :field_selector, label: "X-Axis Field"},
          %{name: "y_axis", type: :field_selector, label: "Y-Axis Field"}
        ]
      }
    },
    
    %{
      name: "styling",
      title: "Styling & Layout", 
      description: "Customize the appearance of your panel",
      
      fields: [
        %{
          name: "theme",
          type: :theme_selector,
          options: ["default", "dark", "minimal", "corporate"],
          default: "default"
        },
        
        %{
          name: "dimensions",
          type: :dimensions_editor,
          fields: [
            %{name: "width", type: :text, default: "800px"},
            %{name: "height", type: :text, default: "400px"}
          ]
        },
        
        %{
          name: "colors",
          type: :color_palette,
          fields: [
            %{name: "primary", type: :color_picker, default: "#3b82f6"},
            %{name: "secondary", type: :color_picker, default: "#6b7280"}
          ]
        }
      ]
    },
    
    %{
      name: "embedding",
      title: "Embedding & Security",
      description: "Configure embedding options and security settings",
      
      fields: [
        %{
          name: "authentication",
          type: :checkbox_group,
          options: [
            %{value: "api_key", label: "API Key Authentication"},
            %{value: "jwt", label: "JWT Token Authentication"},
            %{value: "public", label: "Public Access (No Authentication)"}
          ]
        },
        
        %{
          name: "allowed_origins",
          type: :tag_input,
          label: "Allowed Origins",
          placeholder: "https://example.com",
          description: "Domains that can embed this panel"
        },
        
        %{
          name: "auto_refresh",
          type: :number,
          label: "Auto Refresh Interval (seconds)",
          min: 10,
          max: 3600,
          default: 60
        }
      ]
    }
  ],
  
  # Real-time preview
  preview: %{
    enabled: true,
    position: :right_sidebar,
    responsive_preview: true,
    sample_data: true,
    
    # Preview modes
    modes: [
      %{name: "desktop", width: "800px", height: "400px"},
      %{name: "tablet", width: "600px", height: "300px"},
      %{name: "mobile", width: "320px", height: "240px"}
    ]
  },
  
  # Code generation
  code_generation: %{
    # Generate HTML embed code
    html_embed: true,
    
    # Generate JavaScript integration
    js_integration: true,
    
    # Generate WordPress shortcode
    wordpress_shortcode: true,
    
    # Generate React component
    react_component: true
  }
}
```

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1-3)
- [ ] Magic URL generation and parsing system
- [ ] Basic HTML Custom Element implementation
- [ ] Server-side embed controller and routing
- [ ] Panel configuration schema and validation

### Phase 2: View Implementations (Week 4-6)
- [ ] Aggregate view panel rendering
- [ ] Detail view panel rendering  
- [ ] Graph view panel rendering
- [ ] Interactive features (sorting, filtering, drill-down)

### Phase 3: Builder Interface (Week 7-8)
- [ ] Visual panel builder interface
- [ ] Real-time preview system
- [ ] Code generation for different platforms
- [ ] Panel sharing and publishing

### Phase 4: Advanced Features (Week 9-10)
- [ ] Authentication and authorization system
- [ ] Caching and performance optimization
- [ ] Theme system integration
- [ ] Comprehensive testing and documentation

## Security and Performance

### Authentication Strategies
```elixir
# Multiple authentication methods
auth_strategies = %{
  # API Key authentication
  api_key: %{
    header: "X-API-Key",
    query_param: "api_key",
    validation: &validate_api_key/1,
    permissions: &get_api_key_permissions/1
  },
  
  # JWT token authentication  
  jwt: %{
    header: "Authorization",
    format: "Bearer {token}",
    validation: &validate_jwt_token/1,
    claims_extraction: &extract_jwt_claims/1
  },
  
  # OAuth2 authentication
  oauth2: %{
    header: "Authorization", 
    format: "Bearer {token}",
    introspection_endpoint: "/oauth/introspect",
    cache_duration: 300  # 5 minutes
  },
  
  # Public access (no authentication)
  public: %{
    enabled: true,
    rate_limiting: %{
      requests_per_minute: 60,
      requests_per_hour: 1000
    }
  }
}
```

### Caching Strategy
```elixir
# Multi-level caching for performance
caching_strategy = %{
  # Panel data caching
  data_cache: %{
    backend: :redis,  # or :ets, :mnesia
    default_ttl: 300,  # 5 minutes
    max_size: "1GB",
    eviction_policy: :lru
  },
  
  # Rendered HTML caching
  html_cache: %{
    backend: :ets,
    ttl: 60,  # 1 minute
    vary_by: [:theme, :user_permissions, :config_hash]
  },
  
  # CDN/Browser caching
  http_cache: %{
    static_assets: %{
      max_age: 86400,  # 24 hours
      immutable: true
    },
    
    dynamic_content: %{
      max_age: 300,  # 5 minutes
      stale_while_revalidate: 600  # 10 minutes
    }
  }
}
```

### Performance Optimizations
```elixir
# Performance optimization strategies
performance_optimizations = %{
  # Query optimization
  database: %{
    connection_pooling: true,
    query_timeout: 30000,
    max_results: 10000,
    pagination: true
  },
  
  # Asset optimization
  assets: %{
    css_minification: true,
    js_minification: true,
    gzip_compression: true,
    brotli_compression: true
  },
  
  # Progressive loading
  progressive_loading: %{
    enabled: true,
    skeleton_loading: true,
    lazy_load_images: true,
    chunk_size: 100
  },
  
  # Resource limits
  limits: %{
    max_concurrent_requests: 100,
    max_query_complexity: 1000,
    max_response_size: "10MB"
  }
}
```

## Usage Examples

### WordPress Integration
```html
<!-- WordPress shortcode -->
[selecto_panel src="https://app.com/embed/panel/sales-summary" width="100%" height="400px"]

<!-- Direct HTML -->
<selecto-dashboard-panel 
  src="https://app.com/embed/panel/sales-summary?view=aggregate&group_by=region"
  theme="minimal"
  auto-refresh="60000">
</selecto-dashboard-panel>
```

### React Integration
```jsx
// React component wrapper
import { useEffect, useRef } from 'react';

function SelectoDashboardPanel({ src, config, theme, autoRefresh, ...props }) {
  const panelRef = useRef(null);
  
  useEffect(() => {
    // Ensure the custom element is loaded
    if (!customElements.get('selecto-dashboard-panel')) {
      import('selecto-dashboard-panel');
    }
  }, []);
  
  return (
    <selecto-dashboard-panel
      ref={panelRef}
      src={src}
      config={config ? JSON.stringify(config) : undefined}
      theme={theme}
      auto-refresh={autoRefresh}
      {...props}
    />
  );
}

// Usage
<SelectoDashboardPanel
  src="https://app.com/embed/panel/revenue-trends"
  theme="corporate"
  autoRefresh={30000}
  apiKey="your-api-key"
/>
```

### Static Site Integration
```html
<!DOCTYPE html>
<html>
<head>
  <title>Sales Dashboard</title>
  <script src="https://app.com/embed/assets/dashboard-panel.js"></script>
  <link rel="stylesheet" href="https://app.com/embed/assets/dashboard-panel.css">
</head>
<body>
  <h1>Sales Performance</h1>
  
  <div class="dashboard-grid">
    <selecto-dashboard-panel 
      src="https://app.com/embed/panel/sales-summary"
      width="100%" 
      height="300px"
      theme="minimal">
    </selecto-dashboard-panel>
    
    <selecto-dashboard-panel 
      src="https://app.com/embed/panel/top-products"
      width="100%" 
      height="400px"
      theme="minimal">
    </selecto-dashboard-panel>
  </div>
</body>
</html>
```

## Testing Strategy

### Component Tests
```elixir
test "magic URL generation and parsing" do
  config = sample_panel_config()
  
  # Generate magic URL
  magic_url = SelectoComponents.MagicUrlGenerator.generate_magic_url(config)
  assert magic_url =~ "/embed/panel/"
  
  # Parse magic URL
  {:ok, parsed} = SelectoComponents.MagicUrlGenerator.parse_magic_url(magic_url)
  assert parsed.panel_id == config.id
  assert parsed.config.view.type == config.view.type
end

test "custom element renders correctly" do
  # Test HTML Custom Element functionality
  {:ok, view, html} = live(conn, "/panel-builder")
  
  # Configure a panel
  configure_panel(view, %{
    view: :aggregate,
    group_by: ["region"],
    aggregates: [%{field: "revenue", function: "sum"}]
  })
  
  # Generate embed code
  embed_code = extract_embed_code(view)
  assert embed_code =~ "<selecto-dashboard-panel"
  assert embed_code =~ "src="
end
```

### Integration Tests
```elixir
test "embedded panel loads in iframe" do
  # Set up test panel
  panel_config = create_test_panel()
  
  # Generate magic URL
  magic_url = generate_magic_url(panel_config)
  
  # Test iframe embedding
  {:ok, view, _html} = live(conn, "/test-embed")
  
  # Load panel in iframe
  iframe_url = "#{magic_url}&format=html"
  response = get(conn, iframe_url)
  
  assert response.status == 200
  assert response.resp_body =~ "selecto-table"
end

test "authentication and authorization work correctly" do
  # Test API key authentication
  panel_url = "/embed/panel/protected?api_key=valid_key"
  response = get(conn, panel_url)
  assert response.status == 200
  
  # Test invalid API key
  panel_url = "/embed/panel/protected?api_key=invalid_key"  
  response = get(conn, panel_url)
  assert response.status == 401
  
  # Test CORS headers
  response = get(conn, panel_url, headers: [{"origin", "https://allowed-origin.com"}])
  assert get_resp_header(response, "access-control-allow-origin") == ["https://allowed-origin.com"]
end
```

## Documentation Requirements

- [ ] Complete API reference for magic URLs and Custom Elements
- [ ] Integration guides for popular platforms (WordPress, React, Static Sites)
- [ ] Security best practices and authentication setup
- [ ] Performance optimization guide for high-traffic scenarios
- [ ] Troubleshooting guide for common embedding issues
- [ ] Visual panel builder user guide

## Success Metrics

- [ ] HTML Custom Elements work across all modern browsers
- [ ] Magic URLs support all SelectoComponents view types  
- [ ] Panel builder generates working embed code for major platforms
- [ ] Authentication system supports API keys, JWT, and OAuth2
- [ ] Performance maintains <2s initial load time for panels
- [ ] Caching reduces server load by >80% for repeated requests
- [ ] Security prevents unauthorized access and XSS attacks
- [ ] CORS configuration enables secure cross-origin embedding
- [ ] Responsive design works on mobile, tablet, and desktop
- [ ] Zero breaking changes to existing SelectoComponents API