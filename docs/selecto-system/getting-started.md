# Getting Started with Selecto

Welcome to Selecto! This guide will help you get up and running with the Selecto ecosystem for building dynamic, data-driven applications with Phoenix LiveView.

## 📦 Installation

Add Selecto to your Phoenix application's dependencies:

```elixir
# mix.exs
def deps do
  [
    {:selecto, "~> 0.2.6"},
    {:selecto_components, "~> 0.2.8"},
    {:selecto_mix, "~> 0.1.0"},
    # Optional: For Livebook integration
    {:selecto_kino, "~> 0.1.0"},
    # Optional: For data manipulation
    {:selecto_dome, "~> 0.1.0"}
  ]
end
```

Run the installation:

```bash
mix deps.get
```

## 🏗️ Your First Domain

Domains are the core configuration structures in Selecto that define how your data is organized and accessed.

### Generate a Domain from Ecto Schema

Use the Mix task to automatically generate a domain configuration:

```bash
# Generate domain for a single schema
mix selecto.gen.domain MyApp.Blog.Post

# Generate domains for multiple related schemas
mix selecto.gen.domain.multi MyApp.Blog --include-related

# Generate with dry-run to preview
mix selecto.gen.domain MyApp.Blog.Post --dry-run
```

### Manual Domain Configuration

Create a domain configuration module:

```elixir
# lib/my_app/domains.ex
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

## 🔍 Basic Querying

### Simple Select Query

```elixir
alias MyApp.{Domains, Repo}

# Get all published posts
def get_published_posts do
  Domains.posts_domain()
  |> Selecto.select([:id, :title, :published_at])
  |> Selecto.filter(:published_at, :is_not_null, nil)
  |> Selecto.execute(Repo)
end
```

### Query with Joins

```elixir
def get_posts_with_authors do
  Domains.posts_domain()
  |> Selecto.select([:id, :title, "users.name as author_name"])
  |> Selecto.join(:inner, :users, :author_id, :id)
  |> Selecto.filter(:published_at, :is_not_null, nil)
  |> Selecto.order_by([{:published_at, :desc}])
  |> Selecto.execute(Repo)
end
```

### Advanced Filtering

```elixir
def get_recent_posts(days_ago \\ 7) do
  cutoff_date = DateTime.utc_now() |> DateTime.add(-days_ago, :day)
  
  Domains.posts_domain()
  |> Selecto.select([:id, :title, :published_at])
  |> Selecto.filter(:published_at, :gte, cutoff_date)
  |> Selecto.filter(:title, :ilike, "%elixir%")
  |> Selecto.order_by([{:published_at, :desc}])
  |> Selecto.limit(10)
  |> Selecto.execute(Repo)
end
```

## 🎨 LiveView Integration

### Basic LiveView Setup

```elixir
defmodule MyAppWeb.PostsLive do
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
    <div class="posts-dashboard">
      <.live_component 
        module={SelectoComponents.Form}
        id="posts-view"
        domain={MyApp.Domains.posts_domain()}
        connection={@db_connection}
        filters={@current_filters}
        view_type={:aggregate}
        on_filter_change={&handle_filter_change/1}
      />
    </div>
    """
  end
  
  defp handle_filter_change(new_filters) do
    # Handle filter updates
    send(self(), {:update_filters, new_filters})
  end
end
```

### Router Configuration

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser
  
  live "/posts", PostsLive, :index
end
```

## 🔧 Mix Tasks

Selecto provides several Mix tasks to help with development:

### Domain Generation

```bash
# Generate from single schema
mix selecto.gen.domain MyApp.Blog.Post

# Generate from multiple schemas with relationships
mix selecto.gen.domain.multi MyApp.Blog --include-related

# Export existing domain
mix selecto.gen.domain.export posts_domain --format=json
```

### Documentation

```bash
# Generate all documentation
mix selecto.docs.generate --all --interactive

# Generate API reference
mix selecto.docs.api --all --with-examples

# Generate specific guides
mix selecto.docs.guide --type=getting-started,best-practices
```

### Domain Versioning

```bash
# Create domain version
mix selecto.version.create posts_domain --type=major

# Compare versions
mix selecto.version.compare posts_domain 1.0.0 2.0.0

# Generate migration
mix selecto.version.migrate posts_domain --from=1.0.0 --to=2.0.0
```

## 📊 View Types

SelectoComponents supports three main view types:

### 1. Aggregate View
- Summary statistics and grouped data
- Drill-down navigation capabilities
- Interactive filtering and sorting

### 2. Detail View
- Individual record display
- Pagination and search
- Full CRUD operations (when configured)

### 3. Graph View
- Data visualization charts
- Real-time updates
- Interactive legends and filtering

## 🚀 Next Steps

1. **[Explore Best Practices](best-practices.md)** - Learn recommended patterns and techniques
2. **[Check API Reference](index.md)** - Complete function documentation
3. **[Try Advanced Features](advanced.md)** - CTEs, window functions, and more
4. **[See Examples](https://github.com/selecto/examples)** - Real-world implementations

## 💡 Quick Tips

- Use `--dry-run` flag with Mix tasks to preview changes
- Start with simple domains and gradually add complexity
- Leverage the interactive Livebook tutorials for learning
- Join the community forum for questions and discussions

## 🆘 Need Help?

- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[Community Forum](https://forum.selecto.dev)** - Ask questions and get help
- **[GitHub Issues](https://github.com/selecto/selecto/issues)** - Report bugs and request features

---

**Version**: Selecto Ecosystem v0.2.x  
**Last Updated**: 2025-08-24  
**Compatibility**: Phoenix v1.7+, LiveView v1.1+, Elixir v1.15+