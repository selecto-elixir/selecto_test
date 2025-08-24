# Selecto Troubleshooting Guide

> **⚠️ EXPERIMENTAL SYSTEM**: This documentation describes an experimental system. Features, APIs, and compatibility may change without notice. Use in production at your own risk.

This guide covers common issues and their solutions when working with the Selecto ecosystem.

## 🚨 Common Issues

### 1. Query Execution Errors

#### "relation does not exist" Error

**Problem**: Database table or column not found.

```elixir
# Error message
** (Postgrex.Error) ERROR 42P01 (undefined_table) relation "posts" does not exist
```

**Solutions**:

1. **Verify table name in domain configuration:**
   ```elixir
   # Check your domain configuration
   %{
     source: %{
       source_table: "posts",  # Must match actual table name
       # ...
     }
   }
   ```

2. **Run pending migrations:**
   ```bash
   mix ecto.migrate
   ```

3. **Check database connection:**
   ```elixir
   # In iex
   MyApp.Repo.query("SELECT 1")
   ```

#### Invalid Column Names

**Problem**: Column referenced in query doesn't exist.

```elixir
# Error message
** (Postgrex.Error) ERROR 42703 (undefined_column) column "created_at" does not exist
```

**Solutions**:

1. **Verify column exists in database:**
   ```sql
   \d posts  -- In psql
   ```

2. **Update domain configuration:**
   ```elixir
   fields: [:id, :title, :inserted_at],  # Use actual column name
   columns: %{
     inserted_at: %{type: :datetime}     # Not created_at
   }
   ```

3. **Use field aliases:**
   ```elixir
   |> Selecto.select(["inserted_at as created_at"])
   ```

### 2. Join Configuration Issues

#### Ambiguous Column References

**Problem**: Column name exists in multiple joined tables.

```elixir
# Error message
** (Postgrex.Error) ERROR 42702 (ambiguous_column) column reference "id" is ambiguous
```

**Solutions**:

1. **Use table-qualified column names:**
   ```elixir
   |> Selecto.select(["posts.id", "posts.title", "users.name"])
   ```

2. **Use aliases in domain configuration:**
   ```elixir
   |> Selecto.select([:id, :title, "users.name as author_name"])
   ```

#### Incorrect Join Configuration

**Problem**: Foreign key relationships incorrectly configured.

**Solutions**:

1. **Verify foreign key column names:**
   ```elixir
   joins: %{
     users: {:inner, :author_id, :id}  # posts.author_id = users.id
   }
   ```

2. **Check join direction:**
   ```elixir
   # From posts TO users
   |> Selecto.join(:inner, :users, :author_id, :id)
   
   # From users TO posts (different direction)
   |> Selecto.join(:inner, :posts, :id, :author_id)
   ```

### 3. LiveView Integration Issues

#### Components Not Updating

**Problem**: SelectoComponents don't refresh when data changes.

**Solutions**:

1. **Verify socket assigns:**
   ```elixir
   def handle_info({:data_updated}, socket) do
     # Force component update
     {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__))}
   end
   ```

2. **Check component ID uniqueness:**
   ```elixir
   # Bad: Same ID for multiple components
   <.live_component module={SelectoComponents.Form} id="form" ... />
   <.live_component module={SelectoComponents.Form} id="form" ... />
   
   # Good: Unique IDs
   <.live_component module={SelectoComponents.Form} id="posts-form" ... />
   <.live_component module={SelectoComponents.Form} id="users-form" ... />
   ```

#### JavaScript Hooks Not Working

**Problem**: SelectoComponents interactivity not working.

**Solutions**:

1. **Ensure colocated hooks are compiled:**
   ```bash
   mix compile
   mix assets.build
   ```

2. **Verify Phoenix LiveView version:**
   ```elixir
   # mix.exs - Ensure v1.1+
   {:phoenix_live_view, "~> 1.1"}
   ```

3. **Check browser console for JavaScript errors**

### 4. Performance Issues

#### Slow Query Performance

**Problem**: Queries taking too long to execute.

**Solutions**:

1. **Add database indexes:**
   ```elixir
   # In migration
   create index(:posts, [:status])
   create index(:posts, [:author_id, :status])  # Composite index
   ```

2. **Analyze query execution plan:**
   ```elixir
   # In iex
   query = posts_domain() |> Selecto.to_ecto_query()
   Ecto.Adapters.SQL.explain(MyApp.Repo, :all, query, analyze: true)
   ```

3. **Optimize domain configuration:**
   ```elixir
   # Apply selective filters at domain level
   %{
     source: %{
       default_filters: [
         {:status, :eq, "active"}  # Pre-filter data
       ]
     }
   }
   ```

4. **Use appropriate pagination:**
   ```elixir
   |> Selecto.limit(50)  # Don't load too many records
   |> Selecto.offset(page * 50)
   ```

#### Memory Usage Issues

**Problem**: High memory consumption in LiveView processes.

**Solutions**:

1. **Limit data in socket assigns:**
   ```elixir
   # Bad: Storing large datasets
   assign(socket, posts: all_posts)
   
   # Good: Let components fetch data
   assign(socket, domain: posts_domain(), filters: %{})
   ```

2. **Use streaming for large datasets:**
   ```elixir
   |> Repo.stream()
   |> Stream.chunk_every(100)
   |> Stream.each(&process_chunk/1)
   ```

### 5. Mix Task Issues

#### Domain Generation Fails

**Problem**: `mix selecto.gen.domain` throws errors.

**Solutions**:

1. **Verify Ecto schema exists:**
   ```bash
   # Check schema file exists
   ls lib/my_app/blog/post.ex
   ```

2. **Ensure schema is compiled:**
   ```bash
   mix compile
   mix selecto.gen.domain MyApp.Blog.Post
   ```

3. **Check for schema compilation errors:**
   ```elixir
   # In iex
   MyApp.Blog.Post.__schema__(:fields)
   ```

#### Documentation Generation Issues

**Problem**: `mix selecto.docs.generate` fails.

**Solutions**:

1. **Create docs directory:**
   ```bash
   mkdir -p docs/selecto-system
   ```

2. **Check file permissions:**
   ```bash
   chmod 755 docs/
   ```

3. **Use absolute output paths:**
   ```bash
   mix selecto.docs.generate --output $(pwd)/docs/selecto-system
   ```

### 6. Connection and Database Issues

#### Connection Pool Exhausted

**Problem**: "All connections in pool are busy" error.

```elixir
** (DBConnection.ConnectionError) connection not available and request was dropped from queue after ...ms
```

**Solutions**:

1. **Increase pool size:**
   ```elixir
   # config/config.exs
   config :my_app, MyApp.Repo,
     pool_size: 20  # Increase from default 10
   ```

2. **Check for connection leaks:**
   ```elixir
   # Monitor active connections
   :sys.get_state(MyApp.Repo)
   ```

3. **Use connection timeouts:**
   ```elixir
   Selecto.execute(query, Repo, timeout: 30_000)
   ```

#### Database Timeout Errors

**Problem**: Queries timing out.

**Solutions**:

1. **Increase query timeout:**
   ```elixir
   # config/config.exs
   config :my_app, MyApp.Repo,
     timeout: 30_000,
     ownership_timeout: 60_000
   ```

2. **Optimize slow queries:**
   ```sql
   -- Find slow queries in PostgreSQL
   SELECT query, mean_exec_time, calls 
   FROM pg_stat_statements 
   ORDER BY mean_exec_time DESC;
   ```

## 🔍 Debugging Techniques

### 1. Query Inspection

**View generated SQL:**

```elixir
# In iex
import Ecto.Query

query = posts_domain() 
        |> Selecto.select([:id, :title])
        |> Selecto.to_ecto_query()

IO.inspect(query)

# Or see the actual SQL
Ecto.Adapters.SQL.to_sql(:all, MyApp.Repo, query)
```

**Enable query logging:**

```elixir
# config/dev.exs
config :logger, :console,
  level: :debug

config :my_app, MyApp.Repo,
  log: :debug
```

### 2. Component State Debugging

**Inspect LiveView socket state:**

```elixir
def handle_info(:debug, socket) do
  IO.inspect(socket.assigns, label: "Socket assigns")
  {:noreply, socket}
end

# In iex connected to running app
send(pid, :debug)
```

**Monitor component lifecycle:**

```elixir
def update(assigns, socket) do
  IO.puts("Component updating with: #{inspect(assigns)}")
  {:ok, assign(socket, assigns)}
end
```

### 3. Performance Profiling

**Profile memory usage:**

```elixir
# In iex
:observer.start()

# Or use built-in profiling
{time, result} = :timer.tc(fn -> 
  expensive_query() 
end)
IO.puts("Query took #{time} microseconds")
```

**Monitor database connections:**

```elixir
# Check active connections
MyApp.Repo |> Ecto.Adapters.SQL.query!("SELECT * FROM pg_stat_activity")
```

## 🛠️ Development Tools

### 1. Useful IEx Commands

```elixir
# Reload modules during development
r MyApp.Domains

# Test domain configurations
domain = MyApp.Domains.posts_domain()
Selecto.validate_domain(domain)

# Quick query testing
posts_domain() |> Selecto.select([:id]) |> Selecto.execute(MyApp.Repo)
```

### 2. Database Utilities

```sql
-- PostgreSQL: Check table structure
\d posts

-- Check indexes
\di posts*

-- Analyze table statistics
ANALYZE posts;

-- View query execution plan
EXPLAIN ANALYZE SELECT * FROM posts WHERE status = 'published';
```

### 3. Mix Tasks for Debugging

```bash
# Generate domain with verbose output
mix selecto.gen.domain MyApp.Blog.Post --verbose

# Validate existing domains
mix selecto.validate --all

# Check domain versions
mix selecto.version.list
```

## ⚡ Quick Fixes Checklist

When encountering issues, check these common problems:

- [ ] Database migrations are up to date (`mix ecto.migrate`)
- [ ] Schema modules are compiled (`mix compile`)
- [ ] Domain table names match database tables
- [ ] Foreign key relationships are correctly configured
- [ ] Component IDs are unique in LiveView templates
- [ ] Phoenix LiveView version is 1.1+
- [ ] Colocated hooks are compiled (`mix compile && mix assets.build`)
- [ ] Database connection pool has sufficient capacity
- [ ] Required indexes exist for filtered/joined columns
- [ ] Query timeouts are appropriate for query complexity

## 📞 Getting Help

### Community Resources

- **GitHub Issues**: [https://github.com/selecto/selecto/issues](https://github.com/selecto/selecto/issues)
- **Community Forum**: [https://forum.selecto.dev](https://forum.selecto.dev)
- **Discord Channel**: #selecto on Elixir Discord

### Reporting Bugs

When reporting issues, include:

1. **Elixir/Phoenix versions**
2. **Selecto ecosystem versions**  
3. **Domain configuration** (anonymized)
4. **Full error message and stack trace**
5. **Steps to reproduce**
6. **Database schema** (relevant parts)

### Professional Support

For enterprise support and consulting:
- **Email**: support@selecto.dev
- **Commercial Support**: Available for production deployments

---

**Version**: Selecto Ecosystem v0.2.x (Experimental)  
**Last Updated**: 2025-08-24  
**Next**: [Best Practices](best-practices.md) | [System Overview](system-overview.md)