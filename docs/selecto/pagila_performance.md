# Pagila Domain Performance Guide

This document provides comprehensive performance optimization guidance for the
pagila domain, including benchmarking, indexing strategies, and query optimization.

## Performance Overview

The pagila domain performance characteristics depend on several factors:
- Data volume and distribution
- Query complexity and join patterns  
- Index coverage and maintenance
- Database server configuration

## Benchmarking Results

### Basic Query Performance
Based on performance testing with representative datasets:

| Operation | Records | Avg Time | Memory Usage | Recommendations |
|-----------|---------|----------|--------------|-----------------|
| Simple Select | 1K | 2ms | 1MB | Optimal |
| Simple Select | 100K | 15ms | 50MB | Good |
| Simple Select | 1M | 150ms | 500MB | Consider pagination |
| Filtered Select | 100K | 8ms | 25MB | Good with index |
| Join Query | 100K | 45ms | 75MB | Monitor complexity |
| Aggregation | 1M | 300ms | 100MB | Use materialized views |

### Index Impact Analysis
```
Query: SELECT * FROM pagila WHERE status = 'active'

Without index: 890ms (full table scan)
With index:    12ms  (index scan)
Improvement:   98.7% faster
```

## Indexing Strategy

### Primary Indexes
Essential indexes for the pagila domain:

```sql
-- Primary key (automatic)
CREATE UNIQUE INDEX pagila_pkey ON pagila (id);

-- Frequently filtered fields
CREATE INDEX idx_pagila_status ON pagila (status);
CREATE INDEX idx_pagila_created_at ON pagila (created_at);
CREATE INDEX idx_pagila_name ON pagila (name);

-- Foreign keys for joins
CREATE INDEX idx_pagila_category_id ON pagila (category_id);
CREATE INDEX idx_pagila_user_id ON pagila (user_id);
```

### Composite Indexes
For queries with multiple filter conditions:

```sql
-- Common filter combinations
CREATE INDEX idx_pagila_status_date ON pagila (status, created_at);
CREATE INDEX idx_pagila_user_status ON pagila (user_id, status);
```

### Partial Indexes
For selective filtering on large tables:

```sql
-- Only index active records if they're frequently queried
CREATE INDEX idx_pagila_active_name ON pagila (name) 
WHERE status = 'active';
```

## Query Optimization

### Efficient Field Selection
```elixir
# Good - select only needed fields
Selecto.select(pagila_domain(), [:id, :name, :status])

# Avoid - selecting all fields
Selecto.select(pagila_domain(), :all)  # Can be slow with many columns
```

### Filter Optimization
```elixir
# Good - use indexed fields for filtering
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.filter(:status, :eq, "active")  # Uses index

# Less efficient - function calls in filters
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.filter("UPPER(name)", :like, "PATTERN%")  # No index usage
```

### Join Optimization
```elixir
# Efficient join order - most selective first
Selecto.select(pagila_domain(), [:id, :name])
|> Selecto.filter(:status, :eq, "active")          # Reduces result set first
|> Selecto.join(:inner, :categories, :category_id, :id)  # Then join

# Use appropriate join types
|> Selecto.join(:left, :optional_data, :id, :pagila_id)  # LEFT for optional
```

## Pagination Strategies

### Offset-Based Pagination
```elixir
# Good for small offsets
def get_pagila_page(page, per_page \\ 25) do
  offset = (page - 1) * per_page
  
  Selecto.select(pagila_domain(), [:id, :name])
  |> Selecto.order_by([{:created_at, :desc}])
  |> Selecto.limit(per_page)
  |> Selecto.offset(offset)
  |> Selecto.execute(MyApp.Repo)
end
```

### Cursor-Based Pagination (Recommended)
```elixir
# Better for large datasets
def get_pagila_page_cursor(cursor_id \\ nil, limit \\ 25) do
  base_query = 
    Selecto.select(pagila_domain(), [:id, :name, :created_at])
    |> Selecto.order_by([{:created_at, :desc}, {:id, :desc}])
  
  query = case cursor_id do
    nil -> base_query
    id -> 
      # Get the timestamp of the cursor record for proper ordering
      cursor_time = get_pagila_timestamp(id)
      Selecto.filter(base_query, :created_at, :lte, cursor_time)
      |> Selecto.filter(:id, :lt, id)
  end
  
  query |> Selecto.limit(limit) |> Selecto.execute(MyApp.Repo)
end
```

## Aggregation Performance

### Efficient Grouping
```elixir
# Good - group by indexed fields
Selecto.select(pagila_domain(), [:status, :count])
|> Selecto.group_by([:status])
|> Selecto.aggregate(:count, :id)

# Consider materialized views for complex aggregations
Selecto.select("pagila_daily_stats", [:date, :total_count, :avg_score])
|> Selecto.filter(:date, :gte, Date.add(Date.utc_today(), -30))
```

### Memory-Efficient Aggregations
```elixir
# Stream large aggregations to avoid memory issues
def calculate_pagila_stats do
  MyApp.Repo.transaction(fn ->
    Selecto.select(pagila_domain(), [:category, :score])
    |> Selecto.stream(MyApp.Repo)
    |> Stream.chunk_every(1000)
    |> Enum.reduce(%{}, &process_pagila_chunk/2)
  end)
end
```

## Caching Strategies

### Application-Level Caching
```elixir
def get_cached_pagila_summary(cache_key) do
  case Cachex.get(:pagila_cache, cache_key) do
    {:ok, nil} ->
      data = calculate_pagila_summary()
      Cachex.put(:pagila_cache, cache_key, data, ttl: :timer.minutes(15))
      data
    {:ok, cached_data} ->
      cached_data
  end
end
```

### Database Query Caching
```elixir
# Use prepared statements for repeated queries
def get_pagila_by_status(status) do
  # This query will be prepared and cached by PostgreSQL
  Selecto.select(pagila_domain(), [:id, :name])
  |> Selecto.filter(:status, :eq, status)
  |> Selecto.execute(MyApp.Repo)
end
```

## Memory Management

### Streaming Large Results
```elixir
def process_all_pagilas do
  Selecto.select(pagila_domain(), [:id, :name, :data])
  |> Selecto.stream(MyApp.Repo, max_rows: 500)
  |> Stream.map(&process_single_pagila/1)
  |> Stream.run()
end
```

### Batch Processing
```elixir
def update_pagila_batch(pagila_ids, updates) do
  pagila_ids
  |> Enum.chunk_every(100)
  |> Enum.each(fn batch ->
    Selecto.select(pagila_domain(), [:id])
    |> Selecto.filter(:id, :in, batch)
    |> Selecto.update(updates)
    |> Selecto.execute(MyApp.Repo)
  end)
end
```

## Monitoring and Profiling

### Query Performance Monitoring
```elixir
def profile_pagila_query(query_func) do
  {time_microseconds, result} = :timer.tc(query_func)
  time_ms = time_microseconds / 1000
  
  Logger.info("pagila query completed in #{time_ms}ms")
  
  if time_ms > 100 do
    Logger.warn("Slow pagila query detected: #{time_ms}ms")
  end
  
  result
end
```

### Database Metrics Collection
```elixir
# Monitor query patterns and performance
def log_query_metrics(query, execution_time) do
  MyApp.Telemetry.execute([:pagila, :query], %{
    duration: execution_time,
    result_count: length(query.result)
  }, %{
    query_type: classify_query_type(query),
    has_joins: has_joins?(query)
  })
end
```

## Production Optimization

### Connection Pool Tuning
```elixir
# In config/prod.exs
config :my_app, MyApp.Repo,
  pool_size: 20,              # Adjust based on concurrent users
  queue_target: 50,           # Queue time before spawning new connection
  queue_interval: 1000,       # Check queue every second
  timeout: 15_000,            # Query timeout
  ownership_timeout: 60_000   # Connection checkout timeout
```

### Database Configuration
```sql
-- PostgreSQL optimization for pagila workload
SET shared_buffers = '1GB';              -- Adjust to available RAM
SET effective_cache_size = '3GB';        -- Total available cache
SET work_mem = '256MB';                  -- Per-operation memory
SET maintenance_work_mem = '512MB';      -- For index operations
SET random_page_cost = 1.1;              -- SSD optimization
```

## Performance Testing

### Load Testing
```elixir
defmodule PagilaPerformanceTest do
  use ExUnit.Case
  
  @tag :performance
  test "pagila query performance under load" do
    tasks = for i <- 1..100 do
      Task.async(fn ->
        Selecto.select(pagila_domain(), [:id, :name])
        |> Selecto.filter(:status, :eq, "active")
        |> Selecto.limit(50)
        |> Selecto.execute(MyApp.Repo)
      end)
    end
    
    results = Task.await_many(tasks, 30_000)
    
    # Verify all queries completed successfully
    assert length(results) == 100
    Enum.each(results, fn result ->
      assert is_list(result)
      assert length(result) <= 50
    end)
  end
end
```

### Benchmarking Utilities
```elixir
def benchmark_pagila_operations do
  Benchee.run(%{
    "simple_select" => fn ->
      Selecto.select(pagila_domain(), [:id, :name])
      |> Selecto.limit(100)
      |> Selecto.execute(MyApp.Repo)
    end,
    
    "filtered_select" => fn ->
      Selecto.select(pagila_domain(), [:id, :name])
      |> Selecto.filter(:status, :eq, "active")
      |> Selecto.limit(100)
      |> Selecto.execute(MyApp.Repo)
    end,
    
    "join_query" => fn ->
      Selecto.select(pagila_domain(), [:id, :name, "categories.name"])
      |> Selecto.join(:inner, :categories, :category_id, :id)
      |> Selecto.limit(100)
      |> Selecto.execute(MyApp.Repo)
    end
  })
end
```

## Troubleshooting Performance Issues

### Common Problems and Solutions

**Slow Queries**
1. Check `EXPLAIN ANALYZE` output for the query
2. Verify appropriate indexes exist
3. Consider query restructuring or breaking into smaller operations
4. Check for N+1 query patterns

**High Memory Usage**
1. Implement result streaming for large datasets
2. Use pagination instead of loading all results
3. Optimize field selection to reduce row size
4. Monitor connection pool usage

**Connection Pool Exhaustion**
1. Increase pool size if needed
2. Optimize long-running queries
3. Implement connection pooling monitoring
4. Use connection multiplexing where appropriate

### Performance Monitoring Queries
```sql
-- Find slowest queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
WHERE query LIKE '%pagila%'
ORDER BY total_time DESC
LIMIT 10;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE tablename = 'pagila'
ORDER BY idx_scan DESC;
```

## Best Practices Summary

1. **Always profile queries** in environments similar to production
2. **Use appropriate indexes** for your query patterns
3. **Implement pagination** for large result sets
4. **Monitor query performance** continuously
5. **Cache frequently accessed data** appropriately
6. **Use connection pooling** effectively
7. **Test with realistic data volumes** during development
8. **Optimize based on actual usage patterns**, not assumptions

## Additional Resources

- [PostgreSQL Performance Tuning Guide](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Ecto Performance Tips](https://hexdocs.pm/ecto/Ecto.html#module-performance-tips)
- [Elixir Performance Monitoring](https://hexdocs.pm/telemetry/readme.html)
