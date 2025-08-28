# Window Functions & Analytics Enhancement Plan

## Overview

Add comprehensive window function support to Selecto for advanced analytical queries including ranking, running totals, lag/lead operations, and statistical analysis.

## Architecture Design

### Core Module Structure
```
vendor/selecto/lib/selecto/window.ex           # Main window function API
vendor/selecto/lib/selecto/builder/window.ex   # SQL generation
vendor/selecto/lib/selecto/window/             # Function-specific modules
├── ranking.ex                                 # ROW_NUMBER, RANK, DENSE_RANK
├── offset.ex                                  # LAG, LEAD, FIRST_VALUE, LAST_VALUE  
├── aggregate.ex                               # SUM() OVER, AVG() OVER, etc.
└── frame.ex                                   # ROWS/RANGE window frame handling
```

### API Design

#### Basic Window Functions
```elixir
# Ranking functions
selecto
|> Selecto.window_function(:row_number, over: [partition_by: ["category"], order_by: ["sales_date"]])
|> Selecto.window_function(:rank, over: [partition_by: ["region"], order_by: [{"total_sales", :desc}]])

# Offset functions  
selecto
|> Selecto.window_function(:lag, ["sales_amount", 1], over: [partition_by: ["customer_id"], order_by: ["sales_date"]])
|> Selecto.window_function(:lead, ["sales_amount"], over: [order_by: ["sales_date"]], as: "next_month_sales")

# Aggregate window functions
selecto  
|> Selecto.window_function(:sum, ["sales_amount"], over: [partition_by: ["region"], order_by: ["sales_date"]])
|> Selecto.window_function(:avg, ["sales_amount"], over: [order_by: ["sales_date"], frame: {:rows, :unbounded_preceding, :current_row}])
```

#### Advanced Window Frames
```elixir
# Custom window frames
selecto
|> Selecto.window_function(:sum, ["sales_amount"], 
     over: [
       partition_by: ["customer_id"],
       order_by: ["sales_date"],
       frame: {:rows, {:preceding, 3}, {:following, 1}}  # 3 rows before to 1 row after
     ])

# Range-based frames
selecto  
|> Selecto.window_function(:count, ["*"],
     over: [
       order_by: ["sales_date"], 
       frame: {:range, {:interval, "30 days"}, :current_row}  # 30 days preceding
     ])
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Create `Selecto.Window` API module
- [ ] Basic window function parsing and validation
- [ ] Integration with main Selecto pipeline
- [ ] Support for `ROW_NUMBER()` and `RANK()`

### Phase 2: Core Functions (Week 3-4) 
- [ ] Implement all ranking functions (`DENSE_RANK`, `PERCENT_RANK`, `NTILE`)
- [ ] Add offset functions (`LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`)
- [ ] Basic aggregate window functions (`SUM`, `AVG`, `COUNT`, `MIN`, `MAX`)

### Phase 3: Advanced Features (Week 5-6)
- [ ] Window frame specification (`ROWS`, `RANGE`)
- [ ] Custom frame boundaries (`UNBOUNDED PRECEDING`, `CURRENT ROW`, etc.)
- [ ] Statistical functions (`STDDEV`, `VARIANCE`, `PERCENTILE_CONT`)

### Phase 4: Optimization & Integration (Week 7-8)
- [ ] Query optimization for window functions
- [ ] Integration with existing joins and filters  
- [ ] Performance testing and tuning
- [ ] Comprehensive test suite

## SQL Generation Examples

### Input Selecto Query
```elixir
selecto
|> Selecto.select(["customer_id", "sales_date", "sales_amount"])
|> Selecto.window_function(:row_number, 
     over: [partition_by: ["customer_id"], order_by: ["sales_date"]], 
     as: "sales_sequence")
|> Selecto.window_function(:sum, ["sales_amount"],
     over: [partition_by: ["customer_id"], order_by: ["sales_date"]], 
     as: "running_total")
```

### Generated SQL
```sql
SELECT 
  customer_id,
  sales_date, 
  sales_amount,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY sales_date) AS sales_sequence,
  SUM(sales_amount) OVER (PARTITION BY customer_id ORDER BY sales_date) AS running_total
FROM sales_table
```

## Integration Points

### With Existing Features
- **Joins**: Window functions can reference joined table fields
- **Filters**: WHERE clauses applied before window function calculation  
- **Subselects**: Window functions available in subselect contexts
- **Pivot**: Window functions can operate on pivoted data

### With SelectoComponents
- **Interactive Analytics**: Components can expose window function controls
- **Drill-down**: Window functions enable advanced drill-down patterns
- **Dashboard Views**: Running totals and rankings for dashboard displays
- **Visual Analytics Builder**: UI for building window function queries
- **Time-Series Views**: Built-in support for analytical time-series patterns

## Testing Strategy

### Unit Tests
```elixir
# Test window function SQL generation
test "generates ROW_NUMBER with partition" do
  result = selecto
    |> Selecto.window_function(:row_number, over: [partition_by: ["category"]])
    |> Selecto.to_sql()
    
  assert result =~ "ROW_NUMBER() OVER (PARTITION BY category)"
end

# Test complex window frames
test "generates custom window frame" do 
  result = selecto
    |> Selecto.window_function(:avg, ["amount"], 
         over: [order_by: ["date"], frame: {:rows, {:preceding, 2}, :current_row}])
    |> Selecto.to_sql()
    
  assert result =~ "ROWS 2 PRECEDING AND CURRENT ROW"
end
```

### Integration Tests
- Window functions with joins across multiple tables
- Performance testing with large datasets
- Window function results in SelectoComponents views

## Documentation Requirements

- [ ] API documentation for all window functions
- [ ] Examples for common analytical use cases  
- [ ] Performance considerations and best practices
- [ ] Migration guide from raw SQL window functions
- [ ] Integration examples with SelectoComponents

## Performance Considerations

### Optimization Strategies
- **Partition pruning**: Optimize PARTITION BY clause ordering
- **Index recommendations**: Suggest indexes for ORDER BY columns
- **Memory management**: Handle large window function result sets
- **Query planning**: Optimal placement in query execution plan

### Monitoring
- Query execution time tracking for window function queries
- Memory usage monitoring for large partitions
- Index usage analysis for window function columns

## Migration Path

### Existing Raw SQL Users
```elixir
# Before: Raw SQL in select
selecto |> Selecto.select([{:raw, "ROW_NUMBER() OVER (PARTITION BY category ORDER BY date)"}])

# After: Native Selecto API  
selecto |> Selecto.window_function(:row_number, over: [partition_by: ["category"], order_by: ["date"]])
```

### Backward Compatibility
- Existing raw SQL window functions continue to work
- Gradual migration with deprecation warnings
- Tool to help convert raw SQL to Selecto window function API

## SelectoComponents Integration

### Analytics Dashboard Components

#### Time-Series Analytics View
```elixir
# Enhanced time-series component with window functions
time_series_config = %{
  type: :time_series_analytics,
  selecto: base_query,
  time_field: "created_at",
  
  # Built-in analytical patterns
  analytics: [
    %{
      name: "running_total",
      caption: "Running Total",
      window_function: :sum,
      field: "sales_amount",
      over: [order_by: ["created_at"]],
      format: :currency
    },
    
    %{
      name: "moving_average",
      caption: "30-Day Moving Average", 
      window_function: :avg,
      field: "sales_amount",
      over: [
        order_by: ["created_at"],
        frame: {:rows, {:preceding, 29}, :current_row}
      ],
      format: :currency
    },
    
    %{
      name: "rank_by_sales",
      caption: "Sales Rank",
      window_function: :rank,
      over: [
        partition_by: ["region"],
        order_by: [{"sales_amount", :desc}]
      ],
      format: :integer
    },
    
    %{
      name: "period_over_period",
      caption: "vs Previous Period",
      window_function: :lag,
      field: "sales_amount",
      lag_periods: 1,
      over: [partition_by: ["region"], order_by: ["created_at"]],
      format: :percentage_change
    }
  ],
  
  # Visual presentation
  presentation: %{
    chart_type: :line_with_analytics,
    show_data_table: true,
    interactive_legends: true,
    
    # Window function specific options
    analytics_panel: %{
      enabled: true,
      position: :right,
      collapsible: true,
      
      # User controls for window functions
      user_controls: %{
        moving_average_window: %{
          type: :slider,
          min: 5,
          max: 90,
          default: 30,
          label: "Moving Average Days"
        },
        
        ranking_partition: %{
          type: :multi_select,
          options: ["region", "product_category", "sales_rep"],
          default: ["region"],
          label: "Rank Within"
        }
      }
    }
  }
}
```

#### Ranking and Comparison Views
```elixir
# Ranking dashboard with interactive controls
ranking_view_config = %{
  type: :ranking_analytics,
  selecto: base_query,
  
  # Primary ranking configuration
  ranking: %{
    rank_by: "total_sales",
    partition_by: ["region"],
    time_period: "current_month",
    
    # Multiple ranking methods
    ranking_functions: [
      %{
        function: :row_number,
        name: "position", 
        caption: "Position"
      },
      %{
        function: :rank,
        name: "rank",
        caption: "Rank (with ties)"
      },
      %{
        function: :percent_rank,
        name: "percentile",
        caption: "Percentile",
        format: :percentage
      }
    ]
  },
  
  # Comparison analytics
  comparisons: [
    %{
      name: "vs_previous_period",
      caption: "vs Previous Month",
      window_function: :lag,
      field: "total_sales",
      lag_periods: 1,
      over: [partition_by: ["entity_id"], order_by: ["month"]],
      format: :percentage_change,
      show_trend_arrow: true
    },
    
    %{
      name: "vs_average",
      caption: "vs Group Average",
      calculation: :custom,
      formula: "(total_sales - AVG(total_sales) OVER (PARTITION BY region)) / AVG(total_sales) OVER (PARTITION BY region)",
      format: :percentage
    }
  ],
  
  # Interactive features
  interactions: %{
    # Time period selector
    time_controls: %{
      enabled: true,
      periods: ["current_month", "last_3_months", "ytd", "last_12_months"],
      custom_range: true
    },
    
    # Partition controls
    partition_controls: %{
      enabled: true,
      available_partitions: ["region", "product_category", "sales_team"],
      multi_select: true
    },
    
    # Metric selector
    metric_controls: %{
      enabled: true,
      available_metrics: ["total_sales", "order_count", "avg_order_value"],
      allow_custom_formula: true
    }
  }
}
```

#### Cohort Analysis Component
```elixir
# Cohort analysis using window functions
cohort_analysis_config = %{
  type: :cohort_analytics,
  selecto: user_activity_query,
  
  # Cohort definition
  cohort: %{
    cohort_field: "signup_date",
    cohort_period: :month,  # :week, :month, :quarter
    activity_field: "last_activity_date",
    user_id_field: "user_id"
  },
  
  # Window function calculations
  analytics: [
    %{
      name: "cohort_size",
      caption: "Cohort Size",
      window_function: :count,
      field: "user_id",
      over: [partition_by: ["cohort_month"]],
      calculation_type: :base_cohort
    },
    
    %{
      name: "retention_rate",
      caption: "Retention Rate", 
      window_function: :custom,
      calculation: """
        COUNT(CASE WHEN activity_period >= cohort_period THEN user_id END) * 100.0 /
        FIRST_VALUE(COUNT(user_id)) OVER (
          PARTITION BY cohort_month 
          ORDER BY activity_period 
          ROWS UNBOUNDED PRECEDING
        )
      """,
      format: :percentage
    },
    
    %{
      name: "period_over_period_retention",
      caption: "Retention Change",
      window_function: :lag,
      field: "retention_rate", 
      lag_periods: 1,
      over: [partition_by: ["period_number"], order_by: ["cohort_month"]],
      format: :percentage_change
    }
  ],
  
  # Visualization
  presentation: %{
    chart_type: :cohort_heatmap,
    show_retention_curves: true,
    
    # Interactive controls
    period_selector: %{
      enabled: true,
      options: [:week, :month, :quarter],
      default: :month
    },
    
    date_range_selector: %{
      enabled: true,
      max_cohorts: 12,
      default_range: "last_12_months"
    }
  }
}
```

### Visual Window Function Builder

#### Interactive Builder Component
```elixir
# Visual builder for window functions
window_function_builder_config = %{
  type: :window_function_builder,
  
  # Builder interface sections
  sections: [
    %{
      name: "function_selection",
      title: "Analytics Function",
      description: "Choose the analytical function to apply",
      
      fields: [
        %{
          name: "function_type",
          type: :categorized_select,
          categories: %{
            "Ranking" => [
              %{value: "row_number", label: "Row Number", description: "Sequential numbering"},
              %{value: "rank", label: "Rank", description: "Ranking with ties"},
              %{value: "dense_rank", label: "Dense Rank", description: "Ranking without gaps"},
              %{value: "percent_rank", label: "Percent Rank", description: "Relative ranking (0-1)"},
              %{value: "ntile", label: "Ntile", description: "Divide into N buckets"}
            ],
            
            "Offset" => [
              %{value: "lag", label: "Previous Value (Lag)", description: "Value from N rows before"},
              %{value: "lead", label: "Next Value (Lead)", description: "Value from N rows ahead"},
              %{value: "first_value", label: "First Value", description: "First value in window"},
              %{value: "last_value", label: "Last Value", description: "Last value in window"}
            ],
            
            "Aggregate" => [
              %{value: "sum", label: "Running Sum", description: "Cumulative total"},
              %{value: "avg", label: "Moving Average", description: "Rolling average"},
              %{value: "count", label: "Running Count", description: "Cumulative count"},
              %{value: "min", label: "Running Minimum", description: "Minimum so far"},
              %{value: "max", label: "Running Maximum", description: "Maximum so far"}
            ],
            
            "Statistical" => [
              %{value: "stddev", label: "Standard Deviation", description: "Population std dev"},
              %{value: "variance", label: "Variance", description: "Population variance"},
              %{value: "percentile_cont", label: "Percentile", description: "Continuous percentile"}
            ]
          }
        }
      ]
    },
    
    %{
      name: "field_selection", 
      title: "Field Configuration",
      description: "Configure which field(s) to analyze",
      
      conditional_fields: %{
        # Fields that require a target field
        ["sum", "avg", "min", "max", "stddev", "variance", "lag", "lead"] => [
          %{
            name: "target_field",
            type: :field_selector,
            required: true,
            label: "Field to Analyze",
            field_types: ["numeric", "date", "string"]
          }
        ],
        
        # Offset functions need additional configuration
        ["lag", "lead"] => [
          %{
            name: "offset_periods",
            type: :number,
            min: 1,
            max: 100,
            default: 1,
            label: "Number of Rows"
          }
        ],
        
        # NTILE needs bucket count
        ["ntile"] => [
          %{
            name: "bucket_count",
            type: :number,
            min: 2,
            max: 100,
            default: 4,
            label: "Number of Buckets"
          }
        ]
      }
    },
    
    %{
      name: "partitioning",
      title: "Partitioning",
      description: "Group data for separate calculations",
      
      fields: [
        %{
          name: "partition_by",
          type: :multi_field_selector,
          label: "Partition By (optional)",
          description: "Calculate separately for each group",
          field_types: ["string", "integer", "date"],
          max_selections: 5
        }
      ]
    },
    
    %{
      name: "ordering",
      title: "Ordering",
      description: "Define the order for calculations",
      
      fields: [
        %{
          name: "order_by",
          type: :sort_builder,
          required: true,
          label: "Order By",
          description: "Order determines calculation sequence",
          allow_multiple: true
        }
      ]
    },
    
    %{
      name: "window_frame",
      title: "Window Frame (Advanced)",
      description: "Define which rows to include in calculations",
      
      fields: [
        %{
          name: "frame_type",
          type: :radio_group,
          options: [
            %{value: "default", label: "Default Frame", description: "Use function's default frame"},
            %{value: "rows", label: "Row-based Frame", description: "Count specific rows"},
            %{value: "range", label: "Range-based Frame", description: "Value-based range"}
          ],
          default: "default"
        },
        
        # Conditional frame configuration
        %{
          name: "frame_start",
          type: :select,
          show_when: %{frame_type: ["rows", "range"]},
          options: [
            "unbounded_preceding",
            "preceding_n",
            "current_row"
          ],
          labels: [
            "Start of partition",
            "N rows/values before",
            "Current row"
          ]
        },
        
        %{
          name: "frame_end",
          type: :select,
          show_when: %{frame_type: ["rows", "range"]}, 
          options: [
            "current_row",
            "following_n",
            "unbounded_following"
          ],
          labels: [
            "Current row",
            "N rows/values after",
            "End of partition"
          ]
        }
      ]
    }
  ],
  
  # Real-time preview
  preview: %{
    enabled: true,
    sample_data: true,
    show_sql: true,
    update_on_change: true,
    
    preview_modes: [
      %{name: "table", label: "Data Table"},
      %{name: "chart", label: "Chart View"},
      %{name: "sql", label: "Generated SQL"}
    ]
  },
  
  # Code generation
  output: %{
    elixir_code: true,
    sql_query: true,
    component_config: true,
    
    # Integration with SelectoComponents
    generate_component: %{
      enabled: true,
      component_types: [:time_series, :ranking, :comparison],
      include_interactivity: true
    }
  }
}
```

### Enhanced View Types with Window Functions

#### Trend Analysis Views
```elixir
# Built-in trend analysis patterns
trend_patterns = [
  %{
    name: "growth_rate",
    caption: "Period-over-Period Growth",
    window_functions: [
      %{
        function: :lag,
        field: "value",
        periods: 1,
        calculation: "(current - previous) / previous * 100",
        format: :percentage
      }
    ]
  },
  
  %{
    name: "moving_averages",
    caption: "Moving Averages",
    window_functions: [
      %{
        function: :avg,
        field: "value",
        frame: {:rows, {:preceding, 6}, :current_row},
        name: "7_day_avg"
      },
      %{
        function: :avg,
        field: "value", 
        frame: {:rows, {:preceding, 29}, :current_row},
        name: "30_day_avg"
      }
    ]
  },
  
  %{
    name: "seasonal_analysis",
    caption: "Year-over-Year Comparison",
    window_functions: [
      %{
        function: :lag,
        field: "value",
        periods: 12,  # 12 months ago
        partition_by: ["day_of_year"],
        calculation: "(current - year_ago) / year_ago * 100",
        format: :percentage
      }
    ]
  }
]
```

### Performance Integration

#### Query Optimization for Window Functions
```elixir
# Integration with performance optimization system
window_function_optimizations = %{
  # Index recommendations
  index_analysis: %{
    partition_indexes: true,    # Suggest indexes for PARTITION BY columns
    order_indexes: true,        # Suggest indexes for ORDER BY columns
    composite_indexes: true,    # Multi-column indexes for better performance
    
    recommendations: [
      "CREATE INDEX customers_region_date_idx ON customers (region, created_at)",
      "CREATE INDEX sales_customer_date_idx ON sales (customer_id, sales_date)"
    ]
  },
  
  # Query plan analysis
  execution_plan: %{
    window_sort_detection: true,     # Detect expensive sorts
    memory_usage_estimation: true,   # Estimate memory for window operations
    partition_size_warnings: true    # Warn about large partitions
  },
  
  # Performance monitoring
  monitoring: %{
    window_function_timing: true,
    memory_usage_tracking: true,
    large_partition_alerts: true
  }
}
```

## Success Metrics

- [ ] All major PostgreSQL window functions supported
- [ ] Performance within 5% of hand-written SQL  
- [ ] Zero breaking changes to existing functionality
- [ ] Comprehensive test coverage (>95%)
- [ ] Documentation completeness score >90%
- [ ] SelectoComponents integration with visual builders (>95% coverage)
- [ ] Interactive analytics dashboard components working across all browsers
- [ ] Window function builder generates correct Selecto API calls (100% accuracy)
- [ ] Performance optimization recommendations reduce query time by >30%