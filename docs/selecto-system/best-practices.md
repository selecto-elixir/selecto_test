# Selecto Best Practices

This guide outlines recommended practices for working with the Selecto ecosystem to build maintainable, performant, and scalable applications.

## 🏗️ Domain Design Patterns

### 1. Hierarchical Domain Organization

Structure your domains to reflect your business logic hierarchy:

```elixir
# Good: Organized by business context
defmodule MyApp.Domains do
  # User management domain
  def users_domain, do: %{...}
  
  # Content management domain  
  def content_domain, do: %{...}
  
  # E-commerce domain
  def store_domain, do: %{...}
end

# Better: Separate modules by context
defmodule MyApp.Domains.Users, do: def domain, do: %{...}
defmodule MyApp.Domains.Content, do: def domain, do: %{...}
defmodule MyApp.Domains.Store, do: def domain, do: %{...}
```

### 2. Domain Configuration Principles

**Keep domains focused and cohesive:**

```elixir
# Good: Single responsibility
def blog_posts_domain do
  %{
    source: %{
      source_table: "posts",
      primary_key: :id,
      fields: [:id, :title, :content, :published_at, :author_id]
      # ... focused on posts only
    }
  }
end

# Avoid: Mixed responsibilities
def everything_domain do
  %{
    source: %{
      # Don't mix unrelated tables in one domain
    }
  }
end
```

**Use descriptive field names:**

```elixir
# Good: Clear field names
columns: %{
  id: %{type: :integer, primary_key: true, description: "Post unique identifier"},
  title: %{type: :string, max_length: 255, description: "Post title"},
  created_at: %{type: :datetime, description: "Post creation timestamp"}
}

# Avoid: Vague or abbreviated names
columns: %{
  id: %{type: :integer},
  t: %{type: :string},  # What is 't'?
  dt: %{type: :datetime}  # What is 'dt'?
}
```

### 3. Join Strategy Optimization

**Order joins by cardinality (low to high):**

```elixir
# Good: Start with most selective joins
def optimized_query do
  posts_domain()
  |> Selecto.join(:inner, :categories, :category_id, :id)  # Few categories
  |> Selecto.join(:inner, :authors, :author_id, :id)       # Some authors  
  |> Selecto.join(:left, :comments, :id, :post_id)         # Many comments
end
```

**Use appropriate join types:**

```elixir
# Inner joins for required relationships
|> Selecto.join(:inner, :authors, :author_id, :id)

# Left joins for optional relationships
|> Selecto.join(:left, :categories, :category_id, :id)

# Avoid unnecessary joins
# Don't join tables you're not selecting from or filtering on
```

## 🔍 Query Optimization Strategies

### 1. Filtering Best Practices

**Apply most selective filters first:**

```elixir
# Good: Most selective filter first
def get_recent_published_posts(author_id) do
  posts_domain()
  |> Selecto.filter(:author_id, :eq, author_id)          # Most selective
  |> Selecto.filter(:status, :eq, "published")           # Moderately selective
  |> Selecto.filter(:created_at, :gte, days_ago(7))      # Least selective
  |> Selecto.execute(Repo)
end
```

**Use indexed columns for filtering:**

```elixir
# Ensure database indexes exist for commonly filtered columns
# In your migration:
create index(:posts, [:author_id, :status, :created_at])
```

**Avoid N+1 queries with proper joins:**

```elixir
# Good: Single query with join
def get_posts_with_author_names do
  posts_domain()
  |> Selecto.select([:id, :title, "users.name as author_name"])
  |> Selecto.join(:inner, :users, :author_id, :id)
  |> Selecto.execute(Repo)
end

# Avoid: Separate queries (N+1 problem)
def get_posts_then_authors do
  posts = posts_domain() |> Selecto.execute(Repo)
  Enum.map(posts, fn post ->
    # This creates N additional queries!
    author = users_domain() |> Selecto.filter(:id, :eq, post.author_id) |> Selecto.execute(Repo)
    Map.put(post, :author, author)
  end)
end
```

### 2. Pagination and Limits

**Always use limits for large datasets:**

```elixir
# Good: Reasonable limits
def get_recent_posts(page \\ 1, per_page \\ 25) do
  offset = (page - 1) * per_page
  
  posts_domain()
  |> Selecto.order_by([{:created_at, :desc}])
  |> Selecto.limit(per_page)
  |> Selecto.offset(offset)
  |> Selecto.execute(Repo)
end

# Avoid: No limits on potentially large datasets
def get_all_posts do
  posts_domain() |> Selecto.execute(Repo)  # Could return millions of records!
end
```

**Use cursor-based pagination for high-performance scenarios:**

```elixir
def get_posts_after_cursor(cursor_id, limit \\ 25) do
  posts_domain()
  |> Selecto.filter(:id, :gt, cursor_id)
  |> Selecto.order_by([{:id, :asc}])
  |> Selecto.limit(limit)
  |> Selecto.execute(Repo)
end
```

## 🎨 LiveView Component Patterns

### 1. Component Configuration

**Use descriptive component IDs:**

```elixir
# Good: Descriptive IDs
<.live_component 
  module={SelectoComponents.Form}
  id="user-posts-dashboard"
  domain={@posts_domain}
  view_type={:aggregate}
/>

<.live_component 
  module={SelectoComponents.Form}
  id="admin-user-detail-view"
  domain={@users_domain}
  view_type={:detail}
/>
```

**Configure appropriate view types:**

```elixir
# Use :aggregate for summary views
view_type={:aggregate}    # For dashboards, analytics
grouping_fields={["category", "status"]}
aggregations={[{"count", "*"}, {"avg", "rating"}]}

# Use :detail for record management
view_type={:detail}       # For CRUD operations
pagination={%{per_page: 50}}

# Use :graph for visualizations
view_type={:graph}        # For charts, analytics
chart_type={:line}
```

### 2. State Management

**Keep component state minimal:**

```elixir
def mount(_params, _session, socket) do
  socket = 
    socket
    |> assign(db_connection: MyApp.Repo)
    |> assign(current_domain: MyApp.Domains.posts_domain())
    |> assign(filters: %{})
    # Avoid storing large datasets in assigns
    # Let SelectoComponents handle data fetching
    
  {:ok, socket}
end
```

**Handle filter changes efficiently:**

```elixir
def handle_info({:filter_changed, new_filters}, socket) do
  # Update only the filters, let component refresh data
  {:noreply, assign(socket, filters: new_filters)}
end

# Avoid: Manual data refetching
def handle_info({:filter_changed, new_filters}, socket) do
  # Don't do this - let SelectoComponents handle it
  new_data = fetch_data_with_filters(new_filters)
  {:noreply, assign(socket, filters: new_filters, data: new_data)}
end
```

## 🛡️ Security Best Practices

### 1. Data Access Control

**Implement row-level security in domains:**

```elixir
def user_posts_domain(current_user_id) do
  %{
    source: %{
      source_table: "posts",
      # Apply user-specific filtering at domain level
      default_filters: [
        {:author_id, :eq, current_user_id}
      ]
    }
  }
end
```

**Validate user permissions before query execution:**

```elixir
def get_posts_for_user(user, filters) do
  if authorized_for_posts?(user) do
    user_posts_domain(user.id)
    |> apply_user_filters(filters)
    |> Selecto.execute(Repo)
  else
    {:error, :unauthorized}
  end
end
```

### 2. Input Validation

**Always validate and sanitize inputs:**

```elixir
def build_filters(params) do
  params
  |> validate_filter_params()
  |> sanitize_sql_inputs()
  |> build_selecto_filters()
end

defp validate_filter_params(params) do
  # Use Ecto.Changeset or similar for validation
  changeset = cast({%{}, filter_schema()}, params, [:title, :status, :date_range])
  
  if changeset.valid? do
    {:ok, changeset.changes}
  else
    {:error, changeset.errors}
  end
end
```

**Use parameterized queries (Selecto handles this automatically):**

```elixir
# Good: Selecto automatically parameterizes
|> Selecto.filter(:title, :ilike, user_input)  # Safe from SQL injection

# Avoid: Raw SQL construction
|> Selecto.filter(:title, :ilike, "%#{user_input}%")  # Potentially unsafe
```

## 📊 Performance Optimization

### 1. Database Indexes

**Create indexes for commonly filtered columns:**

```elixir
# In your migrations
defp create_indexes do
  create index(:posts, [:status])
  create index(:posts, [:author_id])
  create index(:posts, [:created_at])
  
  # Composite indexes for common filter combinations
  create index(:posts, [:status, :created_at])
  create index(:posts, [:author_id, :status])
end
```

### 2. Connection Pooling

**Configure appropriate connection pool sizes:**

```elixir
# config/config.exs
config :my_app, MyApp.Repo,
  pool_size: 15,              # Adjust based on your needs
  queue_target: 50,           # Milliseconds
  queue_interval: 1000,       # Milliseconds
  ownership_timeout: 10_000   # For testing
```

### 3. Query Caching

**Implement caching for expensive queries:**

```elixir
def get_post_stats(cache_key) do
  case Cachex.get(:post_cache, cache_key) do
    {:ok, nil} ->
      stats = calculate_expensive_stats()
      Cachex.put(:post_cache, cache_key, stats, ttl: :timer.hours(1))
      stats
      
    {:ok, cached_stats} ->
      cached_stats
  end
end
```

## 🧪 Testing Strategies

### 1. Domain Testing

**Test domain configurations:**

```elixir
defmodule MyApp.DomainsTest do
  use ExUnit.Case
  
  test "posts domain has required fields" do
    domain = MyApp.Domains.posts_domain()
    
    assert domain.source.source_table == "posts"
    assert :id in domain.source.fields
    assert :title in domain.source.fields
  end
end
```

### 2. Query Testing

**Test query building logic:**

```elixir
defmodule MyApp.PostQueriesTest do
  use MyApp.DataCase
  
  test "filters posts by status correctly" do
    published_post = insert(:post, status: "published")
    draft_post = insert(:post, status: "draft")
    
    results = MyApp.Posts.get_published_posts()
    
    assert length(results) == 1
    assert List.first(results).id == published_post.id
  end
end
```

### 3. LiveView Testing

**Test component interactions:**

```elixir
defmodule MyAppWeb.PostsLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest
  
  test "filters posts when form is submitted", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/posts")
    
    # Simulate filter change
    view
    |> element("#posts-filter-form")
    |> render_change(%{filters: %{status: "published"}})
    
    assert has_element?(view, "[data-test='published-post']")
    refute has_element?(view, "[data-test='draft-post']")
  end
end
```

## 🚀 Development Workflow

### 1. Code Organization

**Structure your project logically:**

```
lib/
├── my_app/
│   ├── domains/           # Domain configurations
│   ├── queries/           # Query building functions  
│   └── contexts/          # Business logic contexts
├── my_app_web/
│   ├── live/             # LiveView modules
│   └── components/       # Custom components
```

### 2. Documentation

**Document your domains and queries:**

```elixir
@doc """
Returns posts visible to the given user with optional filtering.

## Parameters
- user: %User{} - The current user
- filters: map() - Optional filters (status, category, date_range)

## Examples
    iex> get_user_posts(user, %{status: "published"})
    {:ok, [%Post{}, ...]}
"""
def get_user_posts(user, filters \\ %{}) do
  # Implementation
end
```

### 3. Version Control

**Use proper branching for domain changes:**

```bash
# Create feature branch for domain changes
git checkout -b feature/add-categories-domain

# Use domain versioning for major changes
mix selecto.version.create posts_domain --type=major

# Commit both code and version files
git add lib/my_app/domains/ priv/selecto/versions/
git commit -m "Add categories support to posts domain"
```

## 🔧 Debugging and Monitoring

### 1. Query Debugging

**Enable query logging in development:**

```elixir
# config/dev.exs
config :my_app, MyApp.Repo,
  log: :debug,
  log_ecto_queries: true
```

**Use explain analyze for performance issues:**

```elixir
# In iex for debugging
query = posts_domain() |> Selecto.to_ecto_query()
Ecto.Adapters.SQL.explain(MyApp.Repo, :all, query, analyze: true, verbose: true)
```

### 2. Error Handling

**Implement proper error handling:**

```elixir
def get_posts_safely(filters) do
  try do
    posts_domain()
    |> apply_filters(filters)
    |> Selecto.execute(Repo)
  rescue
    Ecto.QueryError -> {:error, :invalid_query}
    Postgrex.Error -> {:error, :database_error}
  end
end
```

### 3. Monitoring

**Monitor query performance:**

```elixir
def log_slow_queries(query_time, query_description) when query_time > 1000 do
  Logger.warn("Slow query detected: #{query_description} took #{query_time}ms")
end
```

---

**Version**: Selecto Ecosystem v0.2.x  
**Last Updated**: 2025-08-24  
**Next**: [Troubleshooting Guide](troubleshooting.md) | [API Reference](index.md)