# Selecto Ecosystem - System Overview

> **⚠️ EXPERIMENTAL SYSTEM**: This documentation describes an experimental system. Features, APIs, and compatibility may change without notice. Use in production at your own risk.

Welcome to the comprehensive documentation for the Selecto ecosystem. This system provides a complete toolkit for building dynamic, data-driven applications with Phoenix LiveView.

## 🏗️ Architecture Overview

The Selecto ecosystem consists of several interconnected modules working together to provide a seamless developer experience:

```
┌─────────────────────────────────────────────────────────────┐
│                    Selecto Ecosystem                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Selecto   │  │SelectoComponents│SelectoKino│          │
│  │    Core     │  │  LiveView   │  │  Livebook   │          │
│  │   v0.3.0    │  │   v0.3.0    │  │   v0.3.0    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         │                │               │                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │SelectoDome │  │ SelectoMix  │  │SelectoDev   │          │
│  │Data Manip.  │  │Mix Tasks    │  │Development  │          │
│  │  v0.3.0     │  │  v0.3.0     │  │   Tools     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Core Modules

### 🎯 Selecto (v0.3.0) - Query Builder Core
**Purpose**: Advanced SQL query building with comprehensive join support, CTEs, and OLAP functions.

**Key Features**:
- **Advanced Query Building**: Supports complex queries with joins, CTEs, window functions
- **Domain Configuration**: Rich metadata-driven data modeling
- **Performance Optimization**: Query optimization and execution planning
- **Type Safety**: Compile-time query validation and type checking

**Main Functions**:
- `Selecto.select/2` - Field selection with domain awareness
- `Selecto.filter/4` - Advanced filtering with multiple operators
- `Selecto.join/5` - Complex join operations with optimization
- `Selecto.aggregate/3` - Aggregation functions with grouping
- `Selecto.execute/2` - Query execution with connection pooling

### 🎨 SelectoComponents (v0.3.0) - LiveView Integration
**Purpose**: Interactive data visualization components for Phoenix LiveView with colocated hooks.

**Key Features**:
- **Reactive Components**: Real-time data visualization with drill-down navigation
- **Interactive Forms**: Dynamic filtering and data exploration interfaces  
- **Colocated Hooks**: Phoenix LiveView 1.1+ integration with JavaScript hooks
- **Multiple View Types**: Aggregate, detail, and graph visualizations

**Main Components**:
- `SelectoComponents.Form` - Main data exploration interface
- `SelectoComponents.Aggregate` - Aggregated data views with drill-down
- `SelectoComponents.Detail` - Detailed record views with pagination
- `SelectoComponents.Graph` - Data visualization charts and graphs

### 🔧 SelectoMix (v0.3.0) - Development Tools
**Purpose**: Mix tasks and code generators for Selecto domain configuration and maintenance.

**Key Features**:
- **Domain Generation**: Automatic domain configuration from Ecto schemas
- **Code Generation**: Multi-schema analysis with relationship detection
- **Documentation Generation**: Comprehensive API and guide generation
- **Version Management**: Domain versioning and migration support

**Main Tasks**:
- `mix selecto.gen.domain` - Generate domain configurations
- `mix selecto.docs.generate` - Generate documentation
- `mix selecto.docs.api` - Generate API reference
- `mix selecto.docs.guide` - Generate comprehensive guides

### 📊 SelectoKino (v0.3.0) - Livebook Integration
**Purpose**: Interactive development and exploration tools for Livebook environments.

**Key Features**:
- **Visual Domain Builder**: Drag-and-drop domain configuration
- **Interactive Query Builder**: Visual query construction interface
- **Performance Analysis**: Real-time query performance monitoring
- **Live Data Preview**: Interactive data exploration with sample data

**Main Functions**:
- `SelectoKino.domain_builder/0` - Visual domain configuration
- `SelectoKino.query_builder/1` - Interactive query building
- `SelectoKino.performance_monitor/2` - Performance analysis tools
- `SelectoKino.data_explorer/2` - Interactive data exploration

### 🏢 SelectoDome (v0.3.0) - Data Manipulation Interface
**Purpose**: Advanced data manipulation and change tracking for Selecto query results.

**Key Features**:
- **Change Tracking**: Monitor and track data modifications
- **Data Validation**: Domain-aware data validation rules
- **Batch Operations**: Efficient bulk data operations
- **Audit Trail**: Complete change history and rollback capabilities

### 🛠️ SelectoDev - Development Environment
**Purpose**: Development tools and utilities for Selecto ecosystem development.

**Key Features**:
- **Live Compilation**: Real-time compilation tracking and status
- **Performance Monitoring**: Development-time performance analysis
- **Error Tracking**: Comprehensive error reporting and debugging
- **Live Dashboard**: Development dashboard with system metrics

## 🔗 Integration Patterns

### Phoenix LiveView Integration
```elixir
defmodule MyAppWeb.DataLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(db_connection: MyApp.Repo)
      |> assign(current_filters: %{})
    
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div class="data-dashboard">
      <.live_component 
        module={SelectoComponents.Form}
        id="main-data-view"
        domain={my_domain()}
        connection={@db_connection}
        filters={@current_filters}
        on_filter_change={&handle_filter_change/1}
      />
    </div>
    """
  end
  
  defp my_domain do
    MyApp.Domains.posts_domain()
  end
end
```

### Domain Configuration Pattern
```elixir
defmodule MyApp.Domains do
  def posts_domain do
    %{
      source: %{
        source_table: "posts",
        primary_key: :id,
        fields: [:id, :title, :content, :published_at, :author_id],
        columns: %{
          id: %{type: :integer, primary_key: true},
          title: %{type: :string, max_length: 255},
          content: %{type: :text},
          published_at: %{type: :datetime, nullable: true},
          author_id: %{type: :integer, foreign_key: :users}
        }
      },
      schemas: %{
        authors: %{
          source_table: "users",
          primary_key: :id,
          fields: [:id, :name, :email],
          joins: %{
            posts: {:inner, :author_id, :id}
          }
        }
      }
    }
  end
end
```

### Query Building Pattern
```elixir
def get_published_posts(filters \\ %{}) do
  posts_domain()
  |> Selecto.select([:id, :title, :published_at, "users.name as author_name"])
  |> Selecto.join(:inner, :users, :author_id, :id)
  |> Selecto.filter(:published_at, :is_not_null, nil)
  |> maybe_filter_by_author(filters[:author])
  |> maybe_filter_by_date_range(filters[:date_range])
  |> Selecto.order_by([{:published_at, :desc}])
  |> Selecto.limit(filters[:limit] || 50)
  |> Selecto.execute(MyApp.Repo)
end

defp maybe_filter_by_author(query, nil), do: query
defp maybe_filter_by_author(query, author_id) do
  Selecto.filter(query, :author_id, :eq, author_id)
end

defp maybe_filter_by_date_range(query, nil), do: query
defp maybe_filter_by_date_range(query, {start_date, end_date}) do
  query
  |> Selecto.filter(:published_at, :gte, start_date)
  |> Selecto.filter(:published_at, :lte, end_date)
end
```

## 🎯 Use Cases

### 1. Business Intelligence Dashboards
- **Aggregate Views**: Summary statistics with drill-down capabilities
- **Real-time Updates**: Live data updates with minimal latency
- **Interactive Filtering**: Dynamic data exploration and analysis
- **Export Capabilities**: Data export in multiple formats

### 2. Admin Interfaces
- **CRUD Operations**: Complete data management interfaces
- **Bulk Operations**: Efficient batch data operations
- **Audit Trails**: Complete change tracking and history
- **Role-based Access**: Permission-aware data access

### 3. Data Exploration Tools
- **Interactive Queries**: Visual query building interfaces
- **Performance Analysis**: Query optimization and monitoring
- **Data Visualization**: Charts, graphs, and interactive displays
- **Export and Sharing**: Shareable views and reports

### 4. API Development
- **Query APIs**: RESTful APIs backed by Selecto queries
- **GraphQL Integration**: Dynamic GraphQL resolvers
- **Real-time APIs**: WebSocket-based live data streams
- **Documentation**: Auto-generated API documentation

## 🚀 Performance Characteristics

### Query Performance
- **Optimized SQL Generation**: Efficient query compilation and optimization
- **Connection Pooling**: Database connection management and reuse
- **Query Caching**: Result caching for frequently accessed data
- **Index Recommendations**: Automated performance optimization suggestions

### LiveView Performance
- **Minimal Re-renders**: Efficient DOM updates with targeted changes
- **Component Isolation**: Independent component lifecycle management
- **Colocated Hooks**: Optimized JavaScript integration
- **Memory Management**: Efficient state management and cleanup

### Development Performance
- **Fast Compilation**: Incremental compilation with dependency tracking
- **Hot Reload**: Live code reloading during development
- **Parallel Processing**: Multi-core utilization for build processes
- **Caching**: Comprehensive build artifact caching

## 📈 Scalability

### Horizontal Scaling
- **Database Read Replicas**: Query distribution across multiple databases
- **Connection Pooling**: Efficient database connection management
- **Component Distribution**: Load balancing across multiple nodes
- **Caching Layers**: Redis and ETS-based result caching

### Vertical Scaling
- **Memory Optimization**: Efficient memory usage patterns
- **CPU Optimization**: Multi-core query processing
- **I/O Optimization**: Efficient database and file system operations
- **Resource Monitoring**: Real-time resource usage tracking

## 🔒 Security

### Data Access Security
- **Permission-Aware Queries**: Row-level security integration
- **Field-Level Security**: Sensitive data redaction
- **SQL Injection Prevention**: Parameterized query generation
- **Audit Logging**: Complete access and modification logging

### Application Security
- **Input Validation**: Comprehensive input sanitization
- **CSRF Protection**: Cross-site request forgery prevention
- **XSS Prevention**: Cross-site scripting protection
- **Authentication Integration**: Phoenix authentication compatibility

## 📚 Documentation

### Available Documentation
- **[Getting Started Guide](getting-started.md)** - Complete setup and tutorial
- **[Best Practices Guide](best-practices.md)** - Development patterns and recommendations
- **[API Reference](index.md)** - Complete function documentation
- **[Performance Guide](performance.md)** - Optimization strategies
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[Migration Guide](migration.md)** - Version upgrade instructions

### Interactive Resources
- **[Livebook Tutorials](../notebooks/)** - Interactive learning experiences
- **[Example Applications](https://github.com/selecto/examples)** - Real-world implementations
- **[Community Forum](https://forum.selecto.dev)** - Community support and discussion

## 🛠️ Development Workflow

### Setting Up Development Environment
```bash
# Clone and setup
git clone https://github.com/selecto/selecto_test.git
cd selecto_test
mix setup

# Start development server
mix phx.server

# Or with Livebook integration
iex --sname selecto --cookie COOKIE -S mix phx.server
```

### Code Generation Workflow
```bash
# Generate domain configurations
mix selecto.gen.domain Blog.Post --include-associations

# Generate documentation
mix selecto.docs.generate --all --interactive

# Generate API reference
mix selecto.docs.api --all --with-examples
```

### Testing Workflow
```bash
# Run all tests
mix test

# Run specific test suites
mix test test/selecto_*
mix test test/selecto_components_*
mix test test/selecto_dome_*
```

## 🎉 Getting Started

1. **[Installation Guide](getting-started.md#installation)** - Set up your development environment
2. **[First Domain](getting-started.md#your-first-domain)** - Create your first domain configuration
3. **[LiveView Integration](getting-started.md#liveview-integration)** - Add interactive components
4. **[Advanced Features](advanced.md)** - Explore advanced capabilities

## 📞 Support

- **Documentation**: Comprehensive guides and API reference
- **GitHub Issues**: Bug reports and feature requests
- **Community Forum**: Questions, discussions, and community support
- **Professional Support**: Commercial support and consulting available

---

**Version**: Selecto Ecosystem v0.3.0 (Experimental)  
**Last Updated**: 2025-08-24