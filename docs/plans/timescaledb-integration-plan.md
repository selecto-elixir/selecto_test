# TimescaleDB Integration Plan

## Overview

Integrate Selecto with TimescaleDB, a time-series database built as a PostgreSQL extension, to provide first-class support for time-series analytics, hypertables, continuous aggregates, and temporal queries.

## TimescaleDB Background

TimescaleDB extends PostgreSQL with:
- **Hypertables**: Automatically partitioned tables optimized for time-series data
- **Continuous Aggregates**: Materialized views that refresh incrementally
- **Compression**: Native time-series compression
- **Data Retention**: Automated data lifecycle management
- **Time-series Functions**: Specialized functions for temporal analytics

## Architecture Design

### Core Module Structure
```
vendor/selecto/lib/selecto/timescale/           # TimescaleDB integration
├── hypertable.ex                               # Hypertable operations
├── continuous_aggregate.ex                     # Continuous aggregate support
├── time_bucket.ex                              # Time bucketing functions
├── compression.ex                              # Compression policies
├── retention.ex                                # Data retention policies
└── analytics.ex                               # Time-series analytics functions

vendor/selecto/lib/selecto/builder/timescale.ex # TimescaleDB SQL generation
vendor/selecto/test/timescale_integration_test.exs
```

### API Design

#### Hypertable Operations
```elixir
# Create hypertable-aware domain
domain = %{
  name: "metrics_domain",
  source: %{
    source_table: "metrics",
    timescale: %{
      type: :hypertable,
      time_column: "timestamp",
      partitioning_column: "device_id", # optional
      chunk_time_interval: "1 day"
    }
  }
}

# Query with hypertable optimizations
selecto = Selecto.configure(domain, connection)
  |> Selecto.select(["device_id", "temperature", "timestamp"])
  |> Selecto.timescale_filter(:last_hours, 24)
  |> Selecto.timescale_aggregate(:time_bucket, "1 hour", "temperature", :avg)
```

#### Time Bucketing
```elixir
# Time bucket aggregations
selecto
|> Selecto.select(["device_id"])
|> Selecto.timescale_bucket("1 hour", "timestamp", as: "hour_bucket")
|> Selecto.aggregate([{"temperature", :avg}, {"humidity", :max}])
|> Selecto.group_by(["device_id", "hour_bucket"])
|> Selecto.order_by([{"hour_bucket", :asc}])

# Generate SQL:
# SELECT 
#   device_id,
#   time_bucket('1 hour', timestamp) as hour_bucket,
#   avg(temperature) as temperature_avg,
#   max(humidity) as humidity_max
# FROM metrics
# GROUP BY device_id, hour_bucket
# ORDER BY hour_bucket ASC
```

#### Continuous Aggregates
```elixir
# Define continuous aggregate
continuous_agg = %{
  name: "hourly_metrics",
  query: base_query,
  refresh_policy: %{
    start_offset: "1 hour",
    end_offset: "10 minutes",
    schedule_interval: "10 minutes"
  }
}

# Query continuous aggregate
selecto = Selecto.configure_timescale_cagg(continuous_agg, connection)
  |> Selecto.select(["device_id", "avg_temperature", "bucket"])
  |> Selecto.filter([{"bucket", {:>=, ~N[2023-01-01 00:00:00]}}])
```

#### Time-Series Analytics
```elixir
# Gap filling
selecto
|> Selecto.timescale_gap_fill("timestamp", 
     start: ~N[2023-01-01 00:00:00],
     finish: ~N[2023-01-02 00:00:00],
     interval: "1 hour"
   )
|> Selecto.timescale_interpolate("temperature", method: :linear)

# Time-weighted averages
selecto
|> Selecto.timescale_time_weight("timestamp", "value", 
     method: :linear,
     prev: {~N[2023-01-01 00:00:00], 20.5},
     next: {~N[2023-01-01 02:00:00], 22.1}
   )

# Downsampling with LTTB (Largest Triangle Three Buckets)
selecto
|> Selecto.timescale_lttb("timestamp", "value", threshold: 100)
```

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] TimescaleDB detection and version checking
- [ ] Hypertable metadata introspection
- [ ] Basic time bucketing support
- [ ] Time-based filtering optimizations

### Phase 2: Core Time-Series Functions (Weeks 3-4)  
- [ ] Complete time_bucket implementation
- [ ] Gap filling (time_bucket_gapfill)
- [ ] Interpolation functions (interpolate, locf)
- [ ] Time-weighted averages
- [ ] First/last aggregate functions

### Phase 3: Advanced Analytics (Weeks 5-6)
- [ ] Continuous aggregate support
- [ ] Downsampling algorithms (LTTB, avg, etc.)
- [ ] Time-series statistical functions
- [ ] Compression policy integration

### Phase 4: Management & Optimization (Weeks 7-8)
- [ ] Data retention policies
- [ ] Chunk management
- [ ] Performance optimizations
- [ ] SelectoComponents integration

## TimescaleDB-Specific SQL Generation

### Time Bucketing
```elixir
# Input
selecto |> Selecto.timescale_bucket("5 minutes", "timestamp")
```

```sql
-- Generated SQL
SELECT 
  time_bucket('5 minutes', timestamp) as time_bucket,
  avg(value) as avg_value
FROM sensor_data
WHERE timestamp >= NOW() - INTERVAL '1 day'
GROUP BY time_bucket
ORDER BY time_bucket ASC
```

### Gap Filling
```elixir
# Input
selecto
|> Selecto.timescale_gap_fill("timestamp", 
     interval: "15 minutes",
     start: ~N[2023-01-01 00:00:00],
     finish: ~N[2023-01-01 12:00:00]
   )
|> Selecto.timescale_interpolate("temperature")
```

```sql
-- Generated SQL
SELECT 
  time_bucket_gapfill('15 minutes', timestamp) as bucket,
  interpolate(avg(temperature)) as temperature
FROM sensor_data
WHERE timestamp BETWEEN '2023-01-01 00:00:00' AND '2023-01-01 12:00:00'
GROUP BY bucket
ORDER BY bucket ASC
```

### Continuous Aggregates
```elixir
# Create continuous aggregate (admin operation)
Selecto.Timescale.create_continuous_aggregate(
  "hourly_stats",
  """
  SELECT time_bucket('1 hour', timestamp) as bucket,
         device_id,
         avg(temperature) as avg_temp,
         max(humidity) as max_humidity
  FROM sensor_data
  GROUP BY bucket, device_id
  """,
  refresh_policy: %{interval: "1 hour", lag: "30 minutes"}
)
```

## Time-Series Query Patterns

### Real-time Monitoring
```elixir
# Last 24 hours of data with 5-minute buckets
current_metrics = selecto
  |> Selecto.timescale_bucket("5 minutes", "timestamp")
  |> Selecto.filter([{"timestamp", {:>=, DateTime.add(DateTime.utc_now(), -24, :hour)}}])
  |> Selecto.aggregate([
       {"cpu_usage", :avg},
       {"memory_usage", :avg},
       {"disk_io", :sum}
     ])
  |> Selecto.group_by(["time_bucket", "server_id"])
  |> Selecto.order_by([{"time_bucket", :desc}])
```

### Historical Analysis
```elixir
# Monthly aggregates for the past year
monthly_trends = selecto
  |> Selecto.timescale_bucket("1 month", "timestamp")
  |> Selecto.filter([{"timestamp", {:>=, DateTime.add(DateTime.utc_now(), -365, :day)}}])
  |> Selecto.aggregate([
       {"revenue", :sum},
       {"orders", :count},
       {"avg_order_value", :avg}
     ])
  |> Selecto.group_by(["time_bucket", "region"])
```

### Anomaly Detection
```elixir
# Detect values outside 2 standard deviations
anomalies = selecto
  |> Selecto.select([
       "timestamp",
       "sensor_id", 
       "value",
       {:func, "ABS", ["value", {:func, "AVG", ["value"], over: [partition_by: ["sensor_id"]]}]},
       {:func, "STDDEV", ["value"], over: [partition_by: ["sensor_id"]]}
     ])
  |> Selecto.filter([
       {
         {:func, "ABS", ["value", {:func, "AVG", ["value"], over: [partition_by: ["sensor_id"]]}]}, 
         {:>, {:func, "STDDEV", ["value"], over: [partition_by: ["sensor_id"]]}}
       }
     ])
```

## Performance Optimizations

### Chunk Exclusion
```elixir
# Optimize queries with time-based filters
selecto
|> Selecto.timescale_optimize_chunks()  # Enable chunk exclusion
|> Selecto.filter([{"timestamp", {:between, start_time, end_time}}])
```

### Index Hints
```elixir
# Suggest time-series specific indexes
selecto
|> Selecto.timescale_index_hint(:time_column, "timestamp")
|> Selecto.timescale_index_hint(:space_partition, ["device_id", "timestamp"])
```

### Compression Awareness
```elixir
# Query compressed chunks efficiently
selecto
|> Selecto.timescale_compression_aware()
|> Selecto.select(["device_id", {:func, "FIRST", ["temperature", "timestamp"]}])
```

## Integration Points

### With Existing Selecto Features
- **Window Functions**: Enhanced with time-series optimizations
- **Subfilters**: Time-based EXISTS/IN queries across hypertables  
- **Joins**: Optimized joins between hypertables and regular tables
- **Output Formats**: Time-series specific JSON and CSV formats

### With SelectoComponents
```elixir
# Time-series dashboard component
%{
  type: :time_series_chart,
  query: time_series_query,
  chart_type: :line,
  time_column: "timestamp",
  value_columns: ["temperature", "humidity"],
  aggregation_interval: "1 hour",
  real_time: true
}
```

### With External Tools
- **Grafana Integration**: Generate time-series queries for Grafana dashboards
- **Prometheus Metrics**: Export time-series data in Prometheus format
- **InfluxDB Migration**: Tools for migrating from InfluxDB to TimescaleDB

## Data Types and Schema Considerations

### Time Column Types
```elixir
# Supported time column types
time_column_types = [
  :timestamp,      # TIMESTAMP
  :timestamptz,    # TIMESTAMP WITH TIME ZONE (recommended)
  :date,           # DATE (for daily partitioning)
  :bigint          # Unix timestamp
]
```

### Partitioning Strategies
```elixir
# Space partitioning options
partitioning_options = [
  single_dimension: "timestamp",                    # Time-only partitioning
  multi_dimension: ["timestamp", "device_id"],     # Time + space partitioning
  hash_partition: ["timestamp", {:hash, "user_id", 4}]  # Hash partitioning
]
```

## Testing Strategy

### Unit Tests
```elixir
test "generates time_bucket SQL correctly" do
  result = selecto
    |> Selecto.timescale_bucket("1 hour", "timestamp")
    |> Selecto.to_sql()
    
  assert result =~ "time_bucket('1 hour', timestamp)"
end

test "optimizes chunk exclusion" do
  result = selecto
    |> Selecto.filter([{"timestamp", {:>=, ~N[2023-01-01 00:00:00]}}])
    |> Selecto.to_sql()
    
  # Should include chunk exclusion optimizations
  assert result =~ "timestamp >= ?"
end
```

### Integration Tests
- Query performance with large time-series datasets
- Continuous aggregate refresh behavior
- Compression and decompression scenarios
- Multi-node TimescaleDB clusters

### Performance Benchmarks
- Time-series query performance vs. regular PostgreSQL
- Memory usage with large time ranges
- Continuous aggregate refresh times
- Compression ratios and query speed

## Migration and Deployment

### Hypertable Migration
```elixir
# Convert existing table to hypertable
Selecto.Timescale.Migration.create_hypertable(
  "sensor_data",
  "timestamp",
  chunk_time_interval: "7 days",
  if_not_exists: true
)

# Add space partitioning
Selecto.Timescale.Migration.add_dimension(
  "sensor_data", 
  "device_id",
  number_partitions: 4
)
```

### Continuous Aggregate Setup
```elixir
# Create materialized view for hourly aggregates
defmodule CreateHourlyStats do
  use Ecto.Migration
  
  def up do
    Selecto.Timescale.Migration.create_continuous_aggregate(
      "hourly_device_stats",
      """
      SELECT time_bucket('1 hour', timestamp) as hour,
             device_id,
             avg(cpu_percent) as avg_cpu,
             max(memory_bytes) as max_memory
      FROM device_metrics
      GROUP BY hour, device_id
      """,
      with_data: false
    )
    
    Selecto.Timescale.Migration.add_refresh_policy(
      "hourly_device_stats",
      start_offset: "2 hours",
      end_offset: "1 hour",
      schedule_interval: "1 hour"
    )
  end
end
```

## Error Handling and Validation

### TimescaleDB Extension Detection
```elixir
defmodule Selecto.Timescale.Detection do
  def timescaledb_available?(connection) do
    case Postgrex.query(connection, "SELECT extname FROM pg_extension WHERE extname = 'timescaledb'", []) do
      {:ok, %{rows: [["timescaledb"]]}} -> true
      _ -> false
    end
  end
  
  def timescaledb_version(connection) do
    case Postgrex.query(connection, "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'", []) do
      {:ok, %{rows: [[version]]}} -> {:ok, version}
      error -> {:error, "TimescaleDB not found: #{inspect(error)}"}
    end
  end
end
```

### Schema Validation
```elixir
defmodule Selecto.Timescale.Validation do
  def validate_hypertable_config(config) do
    with :ok <- validate_time_column(config.time_column),
         :ok <- validate_chunk_interval(config.chunk_time_interval),
         :ok <- validate_partitioning(config.partitioning_column) do
      :ok
    else
      {:error, reason} -> {:error, "Invalid hypertable config: #{reason}"}
    end
  end
end
```

## Documentation Requirements

- [ ] Complete API documentation for all TimescaleDB functions
- [ ] Time-series query patterns and best practices
- [ ] Performance tuning guide for time-series workloads  
- [ ] Migration guide from other time-series databases
- [ ] Continuous aggregate management guide
- [ ] Data retention and compression strategies

## Success Metrics

- [ ] All major TimescaleDB functions supported (time_bucket, gap fill, interpolation)
- [ ] Hypertable and continuous aggregate integration
- [ ] Performance within 5% of native TimescaleDB queries
- [ ] Zero breaking changes to existing Selecto functionality
- [ ] Comprehensive test coverage (>95%) 
- [ ] Production deployments with multi-TB time-series datasets

## Future Enhancements

### Advanced Analytics
- [ ] Time-series forecasting functions
- [ ] Seasonal decomposition
- [ ] Change point detection
- [ ] Time-series clustering

### Distributed TimescaleDB
- [ ] Multi-node query optimization
- [ ] Distributed hypertable support
- [ ] Cross-node aggregation
- [ ] Data node failover handling

### Real-time Processing
- [ ] Streaming data ingestion
- [ ] Real-time alerting
- [ ] Event detection
- [ ] Live dashboard updates

This TimescaleDB integration would position Selecto as a comprehensive solution for time-series analytics while maintaining its core strengths in relational data querying.