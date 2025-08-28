# Query Performance Features Enhancement Plan

## Overview

Add intelligent query optimization, performance monitoring, and database-specific tuning capabilities to help Selecto generate efficient SQL and provide actionable performance insights.

## Architecture Design

### Core Module Structure
```
vendor/selecto/lib/selecto/performance/           # Performance features namespace
├── query_hints.ex                               # Database-specific query hints
├── index_advisor.ex                             # Index recommendations
├── query_planner.ex                             # Query plan analysis
├── parallel_query.ex                            # Parallel execution support
├── materialized_views.ex                        # Materialized view integration
├── query_cache.ex                               # Query result caching
└── performance_monitor.ex                       # Query performance tracking
vendor/selecto/lib/selecto/builder/performance.ex # Performance SQL generation
```

### API Design

#### Query Hints
```elixir
# PostgreSQL-specific hints
selecto
|> Selecto.hint(:use_index, ["customers_email_idx"])
|> Selecto.hint(:parallel_workers, 4)
|> Selecto.hint(:work_mem, "256MB")

# Join order hints  
selecto
|> Selecto.hint(:join_order, [:customers, :orders, :order_items])
|> Selecto.hint(:merge_join, {:orders, :customers})

# Cost-based hints
selecto  
|> Selecto.hint(:seq_page_cost, 0.1)
|> Selecto.hint(:random_page_cost, 0.1)
|> Selecto.hint(:cpu_tuple_cost, 0.01)
```

#### Index Recommendations
```elixir
# Analyze query for index opportunities
recommendations = selecto
  |> Selecto.filter([{"email", "user@example.com"}])
  |> Selecto.order_by([{"created_at", :desc}])
  |> Selecto.analyze_indexes()

# Returns:
# [
#   %{
#     type: :btree_index,
#     columns: ["email"],
#     table: "customers", 
#     priority: :high,
#     reason: "Equality filter in WHERE clause",
#     sql: "CREATE INDEX CONCURRENTLY customers_email_idx ON customers(email)"
#   },
#   %{
#     type: :btree_index,
#     columns: ["created_at"],
#     table: "customers",
#     priority: :medium,
#     reason: "ORDER BY clause optimization",
#     sql: "CREATE INDEX CONCURRENTLY customers_created_at_idx ON customers(created_at)"
#   }
# ]
```

#### Query Plan Analysis
```elixir
# Get execution plan without running query
plan = selecto
  |> Selecto.explain(analyze: false, format: :json)

# Get actual execution statistics  
stats = selecto
  |> Selecto.explain(analyze: true, buffers: true, format: :json)

# Analyze plan for performance issues
issues = Selecto.analyze_query_plan(plan)
# [
#   %{issue: :sequential_scan, table: "large_table", cost: 50000.0},
#   %{issue: :hash_join_memory, estimated_memory: "500MB", available_memory: "256MB"}
# ]
```

#### Parallel Query Support
```elixir
# Enable parallel execution for large queries
selecto
|> Selecto.parallel(workers: 4, batch_size: 10000)
|> Selecto.select(["SUM(sales_amount)", "COUNT(*)"])
|> Selecto.group_by(["region"])

# Parallel joins for large table operations
selecto
|> Selecto.parallel_join(:orders, workers: 2)
|> Selecto.filter([{"order_date", {:between, ["2023-01-01", "2023-12-31"]}}])
```

#### Materialized View Integration
```elixir
# Create and manage materialized views
materialized_view = selecto
  |> Selecto.select(["region", "SUM(sales_amount)", "COUNT(*)"])
  |> Selecto.group_by(["region"])
  |> Selecto.materialize(name: "sales_by_region", refresh: :daily)

# Query uses materialized view automatically when beneficial
optimized_query = selecto
  |> Selecto.select(["region", "total_sales"])
  |> Selecto.filter([{"region", "North America"}])
  # Automatically uses sales_by_region materialized view
```

## Implementation Phases

### Phase 1: Query Hints and Analysis (Week 1-3)
- [ ] PostgreSQL-specific hint injection system
- [ ] Query plan retrieval and parsing (EXPLAIN output)
- [ ] Basic performance issue detection
- [ ] Integration with existing SQL generation

### Phase 2: Index Recommendations (Week 4-5)
- [ ] Query pattern analysis for index opportunities
- [ ] Index type recommendations (B-tree, GIN, GiST, etc.)
- [ ] Composite index suggestions for multi-column queries
- [ ] Index usage monitoring and effectiveness tracking

### Phase 3: Parallel Execution (Week 6-7)
- [ ] Parallel query execution for large datasets
- [ ] Connection pooling integration for parallel workers
- [ ] Result merging and aggregation across workers
- [ ] Load balancing and resource management

### Phase 4: Advanced Features (Week 8-10)
- [ ] Materialized view lifecycle management
- [ ] Query result caching with intelligent invalidation
- [ ] Performance monitoring and alerting system
- [ ] Integration with existing monitoring tools

## Query Hint Types

### PostgreSQL-Specific Hints
```sql
-- Generated hints in SQL comments (PostgreSQL extension support)
/*+ USE_INDEX(customers customers_email_idx) */
/*+ PARALLEL(customers 4) */
/*+ SET(work_mem '256MB') */
SELECT * FROM customers WHERE email = 'user@example.com'
```

### Plan Stability Hints
```elixir
# Force specific join algorithms
selecto
|> Selecto.hint(:force_hash_join, {:customers, :orders})
|> Selecto.hint(:disable_nested_loop, {:orders, :order_items})

# Memory allocation hints
selecto
|> Selecto.hint(:work_mem, "512MB")  # For sorts and hash operations
|> Selecto.hint(:maintenance_work_mem, "1GB")  # For index creation
```

## Index Analysis Engine

### Query Pattern Detection
```elixir
# Analyze different query patterns
patterns = [
  %{pattern: :equality_filter, columns: ["email"], priority: :high},
  %{pattern: :range_filter, columns: ["created_at"], priority: :medium},  
  %{pattern: :multi_column_filter, columns: ["status", "region"], priority: :high},
  %{pattern: :order_by, columns: ["created_at"], priority: :medium},
  %{pattern: :group_by, columns: ["region", "status"], priority: :medium}
]
```

### Index Type Selection
- **B-tree**: Equality, range queries, ORDER BY optimization
- **Hash**: Equality queries only (PostgreSQL 10+)
- **GIN**: Full-text search, JSON/JSONB operations, array operations
- **GiST**: Geometric data, full-text search with ranking
- **SP-GiST**: Non-balanced tree structures, IP addresses
- **BRIN**: Very large tables with correlation between physical and logical order

### Composite Index Optimization
```elixir
# Analyze multi-column query patterns
composite_recommendations = [
  %{
    columns: ["status", "created_at"],
    order: [:status, :created_at],  # status first for selectivity
    reason: "Combined WHERE and ORDER BY optimization",
    covering: ["id", "email"]  # Include additional columns for covering index
  }
]
```

## Parallel Query Execution

### Worker Pool Management
```elixir
# Configure parallel execution pool
parallel_config = %{
  max_workers: 8,
  min_workers: 2,
  worker_memory: "256MB",
  coordination_timeout: 30_000,
  batch_strategy: :row_count  # or :data_size, :time_based
}

selecto = Selecto.configure(domain, connection, parallel: parallel_config)
```

### Result Aggregation Strategies
- **Hash-based**: For GROUP BY operations across workers
- **Sort-merge**: For ORDER BY operations across workers  
- **Union**: For simple result combining
- **Streaming**: For real-time result processing

### Load Balancing
```elixir
# Partition data across workers efficiently
partition_strategies = [
  {:hash_partition, "customer_id"},      # Hash-based partitioning
  {:range_partition, "created_at"},      # Time-based partitioning
  {:round_robin, nil},                   # Simple round-robin
  {:custom, custom_partition_function}   # Custom partitioning logic
]
```

## Materialized View Management

### Automatic View Detection
```elixir
# Detect queries suitable for materialization
materialization_candidates = selecto
  |> Selecto.analyze_materialization_opportunities()

# Returns queries with:
# - High execution cost (>1000ms typical)
# - Frequent execution (>10 times/hour)
# - Stable result sets (low data change rate)
# - Complex aggregations or joins
```

### Refresh Strategies
```elixir
# Different refresh approaches
refresh_strategies = [
  {:immediate, []},                           # REFRESH MATERIALIZED VIEW
  {:scheduled, interval: :hourly},            # Cron-based refresh
  {:incremental, trigger_tables: [:orders]}, # Trigger-based incremental refresh
  {:on_demand, conditions: [data_age: "1h"]} # Refresh when data is stale
]
```

### View Lifecycle
```elixir
# Complete materialized view lifecycle
view_manager = %{
  creation: &create_materialized_view/2,
  monitoring: &monitor_view_usage/1,
  optimization: &analyze_view_performance/1, 
  refresh: &refresh_view_strategy/2,
  cleanup: &drop_unused_views/1
}
```

## Performance Monitoring

### Query Performance Metrics
```elixir
# Track query performance over time
metrics = %{
  execution_time: [avg: 150.5, p95: 450.2, p99: 1200.8],
  rows_examined: [avg: 1500, max: 50000],
  memory_usage: [avg: "45MB", peak: "128MB"],
  index_hits: [ratio: 0.95, total: 15420],
  query_frequency: [per_hour: 1200, peak_per_minute: 50]
}
```

### Performance Alerting
```elixir
# Define performance thresholds
alerts = [
  %{
    type: :slow_query,
    threshold: 5000, # 5 seconds
    action: :log_and_notify
  },
  %{
    type: :missing_index,
    threshold: 0.10, # <10% index hit ratio
    action: :suggest_index
  },
  %{
    type: :high_memory,
    threshold: "1GB",
    action: :optimize_query
  }
]
```

## Integration Points

### With Existing Selecto Features
- **Query Generation**: Hints integrated into SQL generation pipeline
- **Connection Pooling**: Parallel workers use existing connection pools
- **Domain Configuration**: Performance settings in domain configuration
- **Error Handling**: Performance errors handled through existing error system

### With External Tools
- **pg_stat_statements**: Integration for query statistics collection
- **EXPLAIN**: Native PostgreSQL query plan analysis
- **Monitoring Tools**: Export metrics to Prometheus, DataDog, etc.
- **APM Tools**: Integration with NewRelic, AppSignal performance monitoring

## Testing Strategy

### Performance Tests
```elixir
test "query hints improve execution time" do
  baseline = measure_query_time(selecto)
  
  optimized_time = selecto
    |> Selecto.hint(:use_index, ["customers_email_idx"])
    |> measure_query_time()
    
  assert optimized_time < baseline * 0.8  # 20% improvement
end

test "parallel execution handles large datasets" do
  large_dataset = generate_test_data(1_000_000)
  
  result = selecto
    |> Selecto.parallel(workers: 4)
    |> Selecto.execute()
    
  assert result.execution_time < sequential_time * 0.6  # 40% improvement
end
```

### Index Recommendation Tests
```elixir
test "recommends appropriate indexes for query patterns" do
  recommendations = selecto
    |> Selecto.filter([{"email", "test@example.com"}])
    |> Selecto.analyze_indexes()
    
  assert Enum.any?(recommendations, fn r -> 
    r.type == :btree_index and "email" in r.columns
  end)
end
```

## Performance Best Practices

### Query Optimization Guidelines
1. **Filter Early**: Apply WHERE clauses before JOINs when possible
2. **Index Strategy**: Ensure indexes cover filter and sort columns
3. **Join Order**: Most selective tables joined first
4. **Memory Usage**: Configure work_mem appropriately for sorts/hashes
5. **Parallel Workers**: Use parallel execution for CPU-intensive operations

### Monitoring Recommendations
1. **Baseline Performance**: Establish performance baselines for critical queries
2. **Regular Analysis**: Run EXPLAIN ANALYZE on slow queries regularly
3. **Index Monitoring**: Track index usage and effectiveness over time
4. **Resource Usage**: Monitor memory, CPU, and I/O usage patterns

## Documentation Requirements

- [ ] Performance tuning guide with PostgreSQL-specific tips
- [ ] Index recommendation interpretation guide
- [ ] Parallel execution configuration and troubleshooting
- [ ] Materialized view management best practices
- [ ] Performance monitoring setup and alerting configuration

## Success Metrics

- [ ] 20%+ query performance improvement on average
- [ ] Automatic index recommendations with >85% accuracy
- [ ] Parallel execution scaling efficiency >70% with 4 workers
- [ ] Zero performance regressions in existing functionality
- [ ] Comprehensive performance test coverage
- [ ] Production-ready monitoring and alerting system