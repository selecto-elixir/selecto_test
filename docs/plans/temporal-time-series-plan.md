# Temporal & Time-Series Enhancement Plan

## Overview

Add comprehensive time-series and temporal data analysis capabilities to Selecto, including time bucketing, gap filling, moving averages, and advanced timezone handling for dashboard and analytics use cases.

## Architecture Design

### Core Module Structure
```
vendor/selecto/lib/selecto/temporal/              # Temporal features namespace
├── time_buckets.ex                               # Time bucketing and grouping
├── gap_filling.ex                                # Missing time point generation
├── moving_averages.ex                            # Window-based calculations
├── timezone_handling.ex                          # Multi-timezone support
├── time_series_functions.ex                      # Specialized time-series functions
└── calendar_operations.ex                        # Business calendar support
vendor/selecto/lib/selecto/builder/temporal.ex    # Temporal SQL generation
```

### API Design

#### Time Bucketing
```elixir
# Group by time intervals
selecto
|> Selecto.time_bucket(:hourly, "created_at", as: "hour_bucket")
|> Selecto.select(["hour_bucket", "COUNT(*)", "SUM(amount)"])
|> Selecto.group_by(["hour_bucket"])

# Custom time intervals
selecto
|> Selecto.time_bucket({:minutes, 15}, "timestamp", as: "quarter_hour")
|> Selecto.time_bucket(:weekly, "created_at", start_of_week: :monday)

# Business time bucketing (excluding weekends/holidays)
selecto
|> Selecto.business_time_bucket(:daily, "order_date", 
     calendar: :us_business, 
     as: "business_day")
```

#### Gap Filling
```elixir
# Fill missing time points with default values
selecto
|> Selecto.time_bucket(:daily, "sales_date")
|> Selecto.select(["sales_date", "COALESCE(SUM(amount), 0)"])
|> Selecto.fill_time_gaps(
     start_date: ~D[2023-01-01],
     end_date: ~D[2023-12-31],
     interval: :daily,
     fill_value: 0
   )

# Generate complete time series
selecto
|> Selecto.generate_time_series(
     from: ~U[2023-01-01 00:00:00Z],
     to: ~U[2023-12-31 23:59:59Z], 
     interval: {:hours, 1},
     as: "time_point"
   )
|> Selecto.left_join(:sales_data, on: [{"time_point", "sales_hour"}])
```

#### Moving Averages and Window Calculations
```elixir
# Simple moving averages
selecto
|> Selecto.select([
     "date",
     "sales_amount",
     {:moving_avg, "sales_amount", window: 7, as: "weekly_avg"},
     {:moving_sum, "sales_amount", window: 30, as: "monthly_total"}
   ])
|> Selecto.order_by([{"date", :asc}])

# Exponential moving averages
selecto
|> Selecto.select([
     "date", 
     "price",
     {:ema, "price", alpha: 0.3, as: "price_ema"},
     {:bollinger_bands, "price", window: 20, std_dev: 2, as: ["bb_upper", "bb_lower"]}
   ])

# Complex time-series calculations
selecto
|> Selecto.select([
     "symbol",
     "date",
     "close_price",
     {:rate_of_change, "close_price", periods: 5, as: "roc_5d"},
     {:relative_strength, "close_price", window: 14, as: "rsi"}
   ])
```

#### Timezone Handling
```elixir
# Multi-timezone support
selecto
|> Selecto.select([
     "event_name",
     {:timezone_convert, "utc_timestamp", "America/New_York", as: "eastern_time"},
     {:timezone_convert, "utc_timestamp", "Europe/London", as: "london_time"},
     {:timezone_convert, "utc_timestamp", "Asia/Tokyo", as: "tokyo_time"}
   ])

# Business hours filtering across timezones
selecto
|> Selecto.filter([
     {:business_hours, "timestamp", timezone: "America/New_York", 
      start_hour: 9, end_hour: 17}
   ])

# Timezone-aware time bucketing
selecto
|> Selecto.time_bucket(:daily, "utc_timestamp", 
     timezone: "America/Chicago", 
     as: "chicago_date")
```

## Implementation Phases

### Phase 1: Basic Time Bucketing (Week 1-2)
- [ ] Core time bucketing functionality (hourly, daily, weekly, monthly)
- [ ] Integration with existing GROUP BY operations
- [ ] PostgreSQL date_trunc() and date_bin() function usage
- [ ] Basic timezone conversion support

### Phase 2: Gap Filling and Series Generation (Week 3-4)
- [ ] Time series generation with generate_series()
- [ ] Gap detection and filling algorithms
- [ ] Missing data interpolation strategies  
- [ ] Integration with LEFT JOINs for gap filling

### Phase 3: Moving Averages and Window Functions (Week 5-6)
- [ ] Simple and weighted moving averages
- [ ] Exponential moving averages (EMA)
- [ ] Statistical indicators (RSI, Bollinger Bands, MACD)
- [ ] Custom window function integration

### Phase 4: Advanced Features (Week 7-8)
- [ ] Business calendar support (holidays, weekends)
- [ ] Multi-timezone query optimization
- [ ] Time-series forecasting helpers
- [ ] Performance optimization for large time-series datasets

## SQL Generation Examples

### Time Bucketing with Aggregation
```elixir
# Input Selecto query
selecto
|> Selecto.time_bucket(:hourly, "created_at", as: "hour")
|> Selecto.select(["hour", "COUNT(*)", "AVG(amount)"])
|> Selecto.group_by(["hour"])
|> Selecto.order_by([{"hour", :asc}])
```

```sql
-- Generated SQL
SELECT 
  date_trunc('hour', created_at) AS hour,
  COUNT(*),
  AVG(amount)
FROM transactions
GROUP BY date_trunc('hour', created_at)
ORDER BY hour ASC
```

### Gap Filling with Time Series
```elixir
# Input Selecto query
selecto
|> Selecto.generate_time_series(
     from: ~D[2023-01-01], 
     to: ~D[2023-01-31],
     interval: :daily,
     as: "date_series"
   )
|> Selecto.left_join(:daily_sales, on: [{"date_series", "sales_date"}])
|> Selecto.select([
     "date_series",
     "COALESCE(total_sales, 0) as sales"
   ])
```

```sql
-- Generated SQL
SELECT 
  date_series,
  COALESCE(ds.total_sales, 0) as sales
FROM generate_series(
  '2023-01-01'::date, 
  '2023-01-31'::date, 
  '1 day'::interval
) AS date_series
LEFT JOIN daily_sales ds ON date_series = ds.sales_date
ORDER BY date_series
```

### Moving Average with Window Functions
```elixir
# Input Selecto query  
selecto
|> Selecto.select([
     "date",
     "price", 
     {:moving_avg, "price", window: 7, as: "sma_7"},
     {:moving_avg, "price", window: 30, as: "sma_30"}
   ])
|> Selecto.order_by([{"date", :asc}])
```

```sql
-- Generated SQL
SELECT 
  date,
  price,
  AVG(price) OVER (ORDER BY date ROWS 6 PRECEDING) AS sma_7,
  AVG(price) OVER (ORDER BY date ROWS 29 PRECEDING) AS sma_30
FROM stock_prices
ORDER BY date ASC
```

## Time Bucketing Strategies

### Standard Intervals
```elixir
bucket_types = [
  :second,      # date_trunc('second', timestamp)
  :minute,      # date_trunc('minute', timestamp)  
  :hour,        # date_trunc('hour', timestamp)
  :day,         # date_trunc('day', timestamp)
  :week,        # date_trunc('week', timestamp)
  :month,       # date_trunc('month', timestamp)
  :quarter,     # date_trunc('quarter', timestamp)
  :year         # date_trunc('year', timestamp)
]
```

### Custom Intervals  
```elixir
custom_intervals = [
  {:minutes, 15},   # 15-minute buckets
  {:hours, 6},      # 6-hour buckets  
  {:days, 7},       # Weekly buckets (7 days)
  {:weeks, 2},      # Bi-weekly buckets
  {:months, 3}      # Quarterly buckets (3 months)
]
```

### Business Time Bucketing
```elixir
# Business calendar support
business_buckets = [
  :business_day,    # Excludes weekends and holidays
  :business_week,   # Monday-Friday weeks only
  :business_month,  # Excludes holidays from monthly calculations
  :business_quarter # Quarterly with business day adjustments
]
```

## Gap Filling Algorithms

### Simple Gap Filling
- **Zero Fill**: Missing values filled with 0
- **Forward Fill**: Use last known value  
- **Backward Fill**: Use next known value
- **Average Fill**: Use average of surrounding values

### Advanced Interpolation
```elixir
interpolation_methods = [
  :linear,          # Linear interpolation between points
  :polynomial,      # Polynomial curve fitting
  :spline,          # Spline interpolation
  :seasonal,        # Seasonal pattern-based filling
  :custom           # User-defined interpolation function
]
```

### Gap Detection
```elixir
# Identify gaps in time series data
gaps = selecto
  |> Selecto.detect_time_gaps(
       time_column: "timestamp",
       expected_interval: {:minutes, 5},
       tolerance: {:seconds, 30}
     )

# Returns gap information:
# [
#   %{start: ~U[2023-01-01 10:15:00Z], end: ~U[2023-01-01 10:45:00Z], duration: "30 minutes"},
#   %{start: ~U[2023-01-01 14:20:00Z], end: ~U[2023-01-01 14:25:00Z], duration: "5 minutes"}
# ]
```

## Moving Average Types

### Simple Moving Average (SMA)
```sql
-- 7-day simple moving average
AVG(price) OVER (ORDER BY date ROWS 6 PRECEDING) AS sma_7
```

### Weighted Moving Average (WMA)
```sql  
-- Recent values weighted more heavily
(price * 7 + LAG(price, 1) * 6 + LAG(price, 2) * 5 + ... + LAG(price, 6) * 1) / 28 AS wma_7
```

### Exponential Moving Average (EMA)
```elixir
# Recursive calculation with smoothing factor
ema_calculation = """
WITH RECURSIVE ema AS (
  SELECT date, price, price AS ema FROM stock_prices WHERE date = (SELECT MIN(date) FROM stock_prices)
  UNION ALL
  SELECT sp.date, sp.price, (alpha * sp.price + (1 - alpha) * e.ema) AS ema
  FROM stock_prices sp JOIN ema e ON sp.date > e.date
  ORDER BY sp.date LIMIT 1
) SELECT * FROM ema
"""
```

## Timezone Handling

### Timezone Conversion Functions
```elixir
timezone_functions = [
  {:at_timezone, "timestamp", "America/New_York"},     # Convert to specific timezone
  {:utc_offset, "timestamp", "timezone_name"},         # Get UTC offset
  {:timezone_name, "timestamp", "America/Chicago"},    # Extract timezone name  
  {:is_dst, "timestamp", "timezone_name"}             # Check if daylight saving time
]
```

### Business Hours Support
```elixir
# Define business hours for different regions
business_hours_config = %{
  "America/New_York" => %{start: 9, end: 17, weekends: false},
  "Europe/London" => %{start: 8, end: 16, weekends: false}, 
  "Asia/Tokyo" => %{start: 9, end: 18, weekends: false}
}

# Filter for business hours across multiple timezones
selecto
|> Selecto.filter([
     {:multi_timezone_business_hours, "utc_timestamp", 
      timezones: ["America/New_York", "Europe/London"]}
   ])
```

### Calendar Integration
```elixir
# Business calendar with holidays
calendar_config = %{
  name: "US_BUSINESS_2023",
  holidays: [
    ~D[2023-01-01],  # New Year's Day
    ~D[2023-07-04],  # Independence Day
    ~D[2023-12-25]   # Christmas Day
  ],
  weekend_days: [:saturday, :sunday],
  custom_rules: [
    {:black_friday_hours, {9, 15}},  # Special hours on Black Friday
    {:summer_hours, {8, 14}, months: [6, 7, 8]}  # Summer hours
  ]
}
```

## Time-Series Indicators

### Technical Analysis Indicators
```elixir
# Common financial indicators
indicators = [
  {:sma, window: 20},                    # Simple Moving Average
  {:ema, alpha: 0.1},                    # Exponential Moving Average
  {:rsi, window: 14},                    # Relative Strength Index
  {:macd, fast: 12, slow: 26, signal: 9}, # MACD
  {:bollinger_bands, window: 20, std: 2}, # Bollinger Bands
  {:stochastic, k: 14, d: 3}             # Stochastic Oscillator
]
```

### Statistical Measures
```elixir
# Time-series statistics
statistics = [
  {:volatility, window: 30},             # Rolling volatility
  {:correlation, "price", "volume", window: 20}, # Rolling correlation
  {:covariance, "price", "benchmark", window: 30}, # Rolling covariance
  {:beta, "price", "market", window: 60}  # Rolling beta calculation
]
```

## Integration Points

### With Existing Features
- **Window Functions**: Time-series calculations use window function infrastructure
- **Joins**: Time bucketing works with joined table time columns
- **Filters**: Timezone-aware filtering integrates with existing filter system
- **Pivot**: Time-bucketed data can be pivoted for cross-time analysis

### With SelectoComponents
```elixir
# Time-series component configurations
time_series_components = [
  %{
    type: :time_chart,
    time_bucket: :daily,
    metrics: ["sales_amount", "order_count"],
    moving_averages: [7, 30],
    timezone: "user_timezone"
  },
  %{
    type: :gap_analysis,
    expected_interval: {:minutes, 5},
    gap_threshold: {:minutes, 10}, 
    fill_strategy: :linear_interpolation
  }
]
```

## Testing Strategy

### Unit Tests
```elixir
test "time bucketing generates correct SQL" do
  result = selecto
    |> Selecto.time_bucket(:hourly, "created_at")
    |> Selecto.to_sql()
    
  assert result =~ "date_trunc('hour', created_at)"
end

test "gap filling generates time series" do
  result = selecto
    |> Selecto.fill_time_gaps(interval: :daily, fill_value: 0)
    |> Selecto.execute()
    
  assert continuous_dates?(result)
end

test "timezone conversion handles DST" do
  # Test across daylight saving time boundary
  result = selecto
    |> Selecto.select([{:timezone_convert, "utc_time", "America/New_York"}])
    |> Selecto.filter([{"utc_time", {:between, [dst_transition_start, dst_transition_end]}}])
    |> Selecto.execute()
    
  assert correct_dst_handling?(result)
end
```

### Performance Tests
- Large time-series dataset processing (millions of time points)
- Moving average calculation performance with different window sizes
- Gap filling performance with sparse data
- Timezone conversion performance across multiple timezones

## Documentation Requirements

- [ ] Complete time-series function reference
- [ ] Business calendar configuration guide
- [ ] Timezone handling best practices  
- [ ] Performance considerations for large time-series datasets
- [ ] Integration examples with SelectoComponents dashboards

## Success Metrics

- [ ] All major time-series operations supported (bucketing, gap filling, moving averages)
- [ ] Accurate timezone handling including DST transitions
- [ ] Performance suitable for real-time dashboard updates (<100ms for typical queries)
- [ ] Business calendar support for common scenarios
- [ ] Comprehensive test coverage including edge cases (>95%)
- [ ] Clear documentation with practical examples