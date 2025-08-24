# Selecto API Reference

Welcome to the comprehensive API documentation for the Selecto ecosystem. This reference covers all modules, functions, and components across the entire Selecto platform.

## 📚 Core Modules

### 🎯 Selecto Core (v0.2.6)

The foundational query building library with advanced SQL generation capabilities.

#### Main Query Functions

**`Selecto.select/2`**
```elixir
select(domain_or_query, fields)
```
Defines the fields to select in the query.

- **Parameters**:
  - `domain_or_query`: Domain configuration map or existing query
  - `fields`: List of field atoms or strings (e.g., `[:id, :title, "users.name as author"]`)
- **Returns**: Updated query structure
- **Example**:
  ```elixir
  posts_domain()
  |> Selecto.select([:id, :title, :published_at])
  ```

**`Selecto.filter/4`**
```elixir
filter(query, field, operator, value)
```
Adds WHERE conditions to the query.

- **Parameters**:
  - `query`: Query structure
  - `field`: Field atom or string
  - `operator`: Filter operator (`:eq`, `:gt`, `:lt`, `:gte`, `:lte`, `:in`, `:like`, `:ilike`, `:is_null`, `:is_not_null`)
  - `value`: Filter value
- **Returns**: Updated query structure
- **Examples**:
  ```elixir
  |> Selecto.filter(:status, :eq, "published")
  |> Selecto.filter(:created_at, :gte, ~D[2023-01-01])
  |> Selecto.filter(:title, :ilike, "%elixir%")
  ```

**`Selecto.join/5`**
```elixir
join(query, type, table, local_key, foreign_key)
```
Adds JOIN clauses to the query.

- **Parameters**:
  - `query`: Query structure
  - `type`: Join type (`:inner`, `:left`, `:right`, `:full`)
  - `table`: Table to join (atom)
  - `local_key`: Local table key (atom)
  - `foreign_key`: Foreign table key (atom)
- **Returns**: Updated query structure
- **Example**:
  ```elixir
  |> Selecto.join(:inner, :users, :author_id, :id)
  ```

**`Selecto.order_by/2`**
```elixir
order_by(query, order_specs)
```
Adds ORDER BY clauses to the query.

- **Parameters**:
  - `query`: Query structure
  - `order_specs`: List of `{field, direction}` tuples where direction is `:asc` or `:desc`
- **Returns**: Updated query structure
- **Example**:
  ```elixir
  |> Selecto.order_by([{:created_at, :desc}, {:title, :asc}])
  ```

**`Selecto.group_by/2`**
```elixir
group_by(query, fields)
```
Adds GROUP BY clauses for aggregation queries.

- **Parameters**:
  - `query`: Query structure
  - `fields`: List of field atoms or strings
- **Returns**: Updated query structure
- **Example**:
  ```elixir
  |> Selecto.group_by([:category, :status])
  ```

**`Selecto.limit/2`** and **`Selecto.offset/2`**
```elixir
limit(query, count)
offset(query, count)
```
Adds LIMIT and OFFSET clauses for pagination.

- **Parameters**:
  - `query`: Query structure
  - `count`: Integer count
- **Returns**: Updated query structure
- **Example**:
  ```elixir
  |> Selecto.limit(25)
  |> Selecto.offset(50)
  ```

**`Selecto.aggregate/3`**
```elixir
aggregate(query, function, field)
```
Adds aggregation functions to the query.

- **Parameters**:
  - `query`: Query structure
  - `function`: Aggregation function (`:count`, `:sum`, `:avg`, `:min`, `:max`)
  - `field`: Field to aggregate (atom or string)
- **Returns**: Updated query structure
- **Example**:
  ```elixir
  |> Selecto.aggregate(:count, "*")
  |> Selecto.aggregate(:avg, :rating)
  ```

**`Selecto.execute/2`**
```elixir
execute(query, repo, opts \\ [])
```
Executes the query against the database.

- **Parameters**:
  - `query`: Query structure
  - `repo`: Ecto repository module
  - `opts`: Optional execution options (timeout, etc.)
- **Returns**: `{:ok, results}` or `{:error, reason}`
- **Example**:
  ```elixir
  |> Selecto.execute(MyApp.Repo, timeout: 30_000)
  ```

#### Advanced Query Functions

**`Selecto.with_cte/3`**
```elixir
with_cte(query, name, cte_query)
```
Adds Common Table Expressions (CTEs) to queries.

**`Selecto.window/3`**
```elixir
window(query, function, options)
```
Adds window functions for advanced analytics.

**`Selecto.union/2`** and **`Selecto.union_all/2`**
```elixir
union(query1, query2)
union_all(query1, query2)
```
Combines multiple queries with UNION operations.

### 🎨 SelectoComponents (v0.2.8)

Interactive Phoenix LiveView components for data visualization.

#### Main Components

**`SelectoComponents.Form`**
The primary component for interactive data exploration.

```elixir
<.live_component 
  module={SelectoComponents.Form}
  id="unique-component-id"
  domain={@domain}
  connection={@db_connection}
  view_type={:aggregate | :detail | :graph}
  filters={@filters}
  grouping_fields={@grouping_fields}
  aggregations={@aggregations}
  pagination={@pagination}
  on_filter_change={@filter_handler}
  on_drill_down={@drill_down_handler}
/>
```

**Component Parameters**:
- `id`: Unique component identifier (required)
- `domain`: Domain configuration map (required)
- `connection`: Database connection/repo (required)
- `view_type`: Display type - `:aggregate`, `:detail`, or `:graph`
- `filters`: Current filter state map
- `grouping_fields`: Fields for grouping in aggregate view
- `aggregations`: List of aggregation specifications
- `pagination`: Pagination configuration map
- `on_filter_change`: Callback for filter updates
- `on_drill_down`: Callback for drill-down navigation

**View Types**:

1. **Aggregate View** (`:aggregate`):
   - Summary statistics and grouped data
   - Drill-down navigation capabilities
   - Interactive filtering and sorting
   - Chart visualizations

2. **Detail View** (`:detail`):
   - Individual record display
   - Pagination and search
   - Record editing (when enabled)
   - Bulk operations

3. **Graph View** (`:graph`):
   - Data visualization charts
   - Real-time updates
   - Interactive legends
   - Multiple chart types

#### Component Configuration

**Filter Configuration**:
```elixir
filters: %{
  status: %{operator: :eq, value: "published"},
  created_at: %{operator: :gte, value: ~D[2023-01-01]},
  title: %{operator: :ilike, value: "%search%"}
}
```

**Aggregation Configuration**:
```elixir
aggregations: [
  %{function: :count, field: "*", alias: "total_count"},
  %{function: :avg, field: "rating", alias: "avg_rating"},
  %{function: :sum, field: "revenue", alias: "total_revenue"}
]
```

**Pagination Configuration**:
```elixir
pagination: %{
  page: 1,
  per_page: 25,
  total_pages: nil,  # Calculated automatically
  total_count: nil   # Calculated automatically
}
```

### 🔧 SelectoMix (v0.1.0)

Mix tasks and code generators for domain configuration.

#### Domain Generation Tasks

**`mix selecto.gen.domain`**
```bash
mix selecto.gen.domain SCHEMA [options]
```
Generates domain configuration from Ecto schema.

**Options**:
- `--dry-run`: Preview changes without creating files
- `--include-associations`: Include related schemas
- `--output`: Specify output directory
- `--format`: Output format (elixir, json, yaml)

**Examples**:
```bash
mix selecto.gen.domain MyApp.Blog.Post --dry-run
mix selecto.gen.domain MyApp.Blog.Post --include-associations
mix selecto.gen.domain MyApp.Blog.Post --output lib/domains/
```

**`mix selecto.gen.domain.multi`**
```bash
mix selecto.gen.domain.multi CONTEXT [options]
```
Generates domains for multiple related schemas.

**Examples**:
```bash
mix selecto.gen.domain.multi MyApp.Blog --include-related
mix selecto.gen.domain.multi MyApp.Store --detect-hierarchies
```

#### Documentation Generation Tasks

**`mix selecto.docs.generate`**
```bash
mix selecto.docs.generate [options]
```
Generates comprehensive domain documentation.

**Options**:
- `--all`: Generate all documentation types
- `--interactive`: Include interactive examples
- `--output`: Output directory
- `--domain`: Specific domain to document

**`mix selecto.docs.api`**
```bash
mix selecto.docs.api [options]
```
Generates API reference documentation.

**`mix selecto.docs.guide`**
```bash
mix selecto.docs.guide [options]
```
Generates tutorial and guide documentation.

#### Domain Versioning Tasks

**`mix selecto.version.create`**
```bash
mix selecto.version.create DOMAIN_NAME --type=TYPE
```
Creates a new version of a domain configuration.

**`mix selecto.version.compare`**
```bash
mix selecto.version.compare DOMAIN_NAME VERSION1 VERSION2
```
Compares two versions of a domain.

**`mix selecto.version.migrate`**
```bash
mix selecto.version.migrate DOMAIN_NAME --from=V1 --to=V2
```
Generates migration between domain versions.

### 📊 SelectoKino (v0.1.0)

Interactive development tools for Livebook environments.

#### Interactive Widgets

**`SelectoKino.domain_builder/0`**
```elixir
SelectoKino.domain_builder()
```
Visual domain configuration interface.

**`SelectoKino.query_builder/1`**
```elixir
SelectoKino.query_builder(domain)
```
Interactive query building interface.

**`SelectoKino.performance_monitor/2`**
```elixir
SelectoKino.performance_monitor(query, repo)
```
Real-time performance analysis tools.

**`SelectoKino.data_explorer/2`**
```elixir
SelectoKino.data_explorer(domain, repo)
```
Interactive data exploration interface.

### 🏢 SelectoDome (v0.1.0)

Data manipulation interface for Selecto query results.

#### Core Functions

**`SelectoDome.track_changes/2`**
```elixir
track_changes(data, options)
```
Enables change tracking for query results.

**`SelectoDome.apply_changes/2`**
```elixir
apply_changes(tracked_data, repo)
```
Applies tracked changes to the database.

**`SelectoDome.validate_changes/2`**
```elixir
validate_changes(tracked_data, domain)
```
Validates changes against domain constraints.

## 📋 Configuration Reference

### Domain Configuration Structure

```elixir
%{
  source: %{
    source_table: "table_name",           # Database table name
    primary_key: :id,                     # Primary key field
    fields: [:id, :name, :email],         # Available fields
    columns: %{                           # Column definitions
      id: %{type: :integer, primary_key: true},
      name: %{type: :string, max_length: 255},
      email: %{type: :string, unique: true}
    },
    default_filters: [                    # Always applied filters
      {:status, :eq, "active"}
    ],
    custom_fields: %{                     # Computed fields
      full_name: "CONCAT(first_name, ' ', last_name)"
    }
  },
  schemas: %{                            # Related schemas
    posts: %{
      source_table: "posts",
      primary_key: :id,
      fields: [:id, :title, :author_id],
      joins: %{                          # Join definitions
        author: {:inner, :author_id, :id}
      }
    }
  },
  metadata: %{                           # Optional metadata
    description: "User management domain",
    version: "1.0.0",
    context_name: "Accounts"
  }
}
```

### Column Type Reference

| Type | Description | Options |
|------|-------------|---------|
| `:integer` | Integer numbers | `primary_key`, `auto_increment` |
| `:string` | Variable length text | `max_length`, `unique` |
| `:text` | Long text content | - |
| `:boolean` | True/false values | `default` |
| `:datetime` | Date and time | `precision`, `timezone` |
| `:date` | Date only | - |
| `:time` | Time only | `precision` |
| `:decimal` | Decimal numbers | `precision`, `scale` |
| `:float` | Floating point | `precision` |
| `:binary` | Binary data | `max_length` |
| `:uuid` | UUID values | `primary_key` |

### Filter Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `:eq` | Equal to | `{:status, :eq, "active"}` |
| `:ne` | Not equal to | `{:status, :ne, "deleted"}` |
| `:gt` | Greater than | `{:age, :gt, 18}` |
| `:gte` | Greater than or equal | `{:created_at, :gte, ~D[2023-01-01]}` |
| `:lt` | Less than | `{:score, :lt, 100}` |
| `:lte` | Less than or equal | `{:updated_at, :lte, DateTime.utc_now()}` |
| `:in` | In list | `{:category, :in, ["tech", "news"]}` |
| `:not_in` | Not in list | `{:status, :not_in, ["deleted", "spam"]}` |
| `:like` | SQL LIKE (case sensitive) | `{:name, :like, "John%"}` |
| `:ilike` | SQL ILIKE (case insensitive) | `{:title, :ilike, "%elixir%"}` |
| `:is_null` | IS NULL | `{:deleted_at, :is_null, nil}` |
| `:is_not_null` | IS NOT NULL | `{:published_at, :is_not_null, nil}` |

### Aggregation Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `:count` | Count records | `aggregate(:count, "*")` |
| `:sum` | Sum numeric values | `aggregate(:sum, :revenue)` |
| `:avg` | Average of values | `aggregate(:avg, :rating)` |
| `:min` | Minimum value | `aggregate(:min, :created_at)` |
| `:max` | Maximum value | `aggregate(:max, :updated_at)` |
| `:string_agg` | Concatenate strings | `aggregate(:string_agg, :tags)` |

## 🔗 Integration Examples

### Phoenix LiveView Integration

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(domain: MyApp.Domains.analytics_domain())
      |> assign(connection: MyApp.Repo)
      |> assign(filters: %{})
      |> assign(view_type: :aggregate)
    
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div class="dashboard">
      <.live_component 
        module={SelectoComponents.Form}
        id="analytics-dashboard"
        domain={@domain}
        connection={@connection}
        view_type={@view_type}
        filters={@filters}
        grouping_fields={["category", "status"]}
        aggregations={[
          %{function: :count, field: "*", alias: "total"},
          %{function: :sum, field: "revenue", alias: "revenue"}
        ]}
      />
    </div>
    """
  end
end
```

### GraphQL Integration

```elixir
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  
  object :post_analytics do
    field :total_posts, :integer
    field :avg_rating, :float
    field :categories, list_of(:string)
  end
  
  query do
    field :post_analytics, :post_analytics do
      arg :filters, :post_filters
      
      resolve fn args, _info ->
        MyApp.Domains.posts_domain()
        |> apply_graphql_filters(args[:filters])
        |> Selecto.aggregate(:count, "*")
        |> Selecto.aggregate(:avg, :rating)
        |> Selecto.execute(MyApp.Repo)
      end
    end
  end
end
```

---

**Version**: Selecto Ecosystem v0.2.x  
**Last Updated**: 2025-08-24  
**Compatibility**: Phoenix v1.7+, LiveView v1.1+, Elixir v1.15+

For more detailed examples and tutorials, see:
- [Getting Started Guide](getting-started.md)
- [Best Practices](best-practices.md)
- [System Overview](system-overview.md)