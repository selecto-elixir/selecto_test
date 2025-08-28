# Pagila Domain Examples

This document provides practical examples of using the pagila domain for
common data querying and visualization scenarios.

## Basic Operations

### Simple Data Retrieval
```elixir
# Get all records with basic fields
pagila_data = 
  Selecto.select(pagila_domain(), [:id, :name])
  |> Selecto.limit(50)
  |> Selecto.execute(MyApp.Repo)

# Get single record by ID
single_pagila = 
  Selecto.select(pagila_domain(), [:id, :name, :created_at])
  |> Selecto.filter(:id, :eq, 123)
  |> Selecto.execute(MyApp.Repo)
  |> List.first()
```

### Filtering Examples
```elixir
# String filtering
filtered_data = 
  Selecto.select(pagila_domain(), [:id, :name])
  |> Selecto.filter(:name, :like, "%search%")
  |> Selecto.execute(MyApp.Repo)

# Multiple filters with AND logic
complex_filter = 
  Selecto.select(pagila_domain(), [:id, :name, :created_at])
  |> Selecto.filter(:name, :like, "%active%")
  |> Selecto.filter(:created_at, :gte, ~D[2024-01-01])
  |> Selecto.execute(MyApp.Repo)

# OR logic using filter groups
or_filter = 
  Selecto.select(pagila_domain(), [:id, :name])
  |> Selecto.filter_group(:or, [
    {:name, :like, "%urgent%"},
    {:priority, :eq, "high"}
  ])
  |> Selecto.execute(MyApp.Repo)
```

## Aggregation Examples

### Basic Aggregations
```elixir
# Count total records
total_count = 
  Selecto.select(pagila_domain(), [:count])
  |> Selecto.aggregate(:count, :id)
  |> Selecto.execute(MyApp.Repo)
  |> hd()
  |> Map.get(:count)

# Group by category with counts
category_counts = 
  Selecto.select(pagila_domain(), [:category, :count])
  |> Selecto.group_by([:category])
  |> Selecto.aggregate(:count, :id)
  |> Selecto.order_by([{:count, :desc}])
  |> Selecto.execute(MyApp.Repo)
```

### Advanced Aggregations
```elixir
# Multiple aggregations
summary_stats = 
  Selecto.select(pagila_domain(), [:category, :total_count, :avg_score, :max_date])
  |> Selecto.group_by([:category])
  |> Selecto.aggregate(:count, :id, alias: :total_count)
  |> Selecto.aggregate(:avg, :score, alias: :avg_score)
  |> Selecto.aggregate(:max, :created_at, alias: :max_date)
  |> Selecto.execute(MyApp.Repo)

# Conditional aggregations
conditional_stats = 
  Selecto.select(pagila_domain(), [
    :status,
    "COUNT(CASE WHEN priority = 'high' THEN 1 END) as high_priority_count",
    "COUNT(CASE WHEN priority = 'low' THEN 1 END) as low_priority_count"
  ])
  |> Selecto.group_by([:status])
  |> Selecto.execute(MyApp.Repo)
```

## Join Examples

### Simple Joins
```elixir
# Inner join with categories
pagila_with_categories = 
  Selecto.select(pagila_domain(), [:id, :name, "categories.name as category_name"])
  |> Selecto.join(:inner, :categories, :category_id, :id)
  |> Selecto.execute(MyApp.Repo)

# Left join to include records without categories
all_pagila_with_optional_categories = 
  Selecto.select(pagila_domain(), [:id, :name, "categories.name as category_name"])
  |> Selecto.join(:left, :categories, :category_id, :id)
  |> Selecto.execute(MyApp.Repo)
```

### Complex Joins
```elixir
# Multiple joins with aggregation
pagila_summary = 
  Selecto.select(pagila_domain(), [
    :id, :name,
    "COUNT(comments.id) as comment_count",
    "AVG(ratings.score) as avg_rating"
  ])
  |> Selecto.join(:left, :comments, :id, :pagila_id)
  |> Selecto.join(:left, :ratings, :id, :pagila_id)
  |> Selecto.group_by([:id, :name])
  |> Selecto.execute(MyApp.Repo)
```

## LiveView Integration Examples

### Basic LiveView Setup
```elixir
defmodule MyAppWeb.PagilaLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    {:ok, load_pagila_data(socket)}
  end
  
  defp load_pagila_data(socket) do
    pagila_data = 
      Selecto.select(pagila_domain(), [:id, :name, :created_at])
      |> Selecto.order_by([{:created_at, :desc}])
      |> Selecto.limit(25)
      |> Selecto.execute(MyApp.Repo)
    
    assign(socket, pagila_data: pagila_data)
  end
end
```

### Interactive Filtering
```elixir
def handle_event("filter", %{"search" => search_term}, socket) do
  filtered_data = 
    Selecto.select(pagila_domain(), [:id, :name, :created_at])
    |> maybe_filter_by_search(search_term)
    |> Selecto.order_by([{:created_at, :desc}])
    |> Selecto.limit(25)
    |> Selecto.execute(MyApp.Repo)
  
  {:noreply, assign(socket, pagila_data: filtered_data)}
end

defp maybe_filter_by_search(query, ""), do: query
defp maybe_filter_by_search(query, search_term) do
  Selecto.filter(query, :name, :ilike, "%#{search_term}%")
end
```

### Pagination Example
```elixir
def handle_event("load_more", _params, socket) do
  current_data = socket.assigns.pagila_data
  offset = length(current_data)
  
  new_data = 
    Selecto.select(pagila_domain(), [:id, :name, :created_at])
    |> Selecto.order_by([{:created_at, :desc}])
    |> Selecto.limit(25)
    |> Selecto.offset(offset)
    |> Selecto.execute(MyApp.Repo)
  
  updated_data = current_data ++ new_data
  
  {:noreply, assign(socket, pagila_data: updated_data)}
end
```

## SelectoComponents Integration

### Aggregate View
```elixir
# In your LiveView template
<.live_component 
  module={SelectoComponents.Aggregate} 
  id="pagila-aggregate"
  domain={pagila_domain()}
  connection={@db_connection}
  initial_fields={[:id, :name, :category]}
  initial_aggregates={[:count]}
/>
```

### Detail View with Drill-Down
```elixir
<.live_component 
  module={SelectoComponents.Detail} 
  id="pagila-detail"
  domain={pagila_domain()}
  connection={@db_connection}
  filters={@current_filters}
  on_row_click={&handle_pagila_selected/1}
/>
```

## Performance Optimization Examples

### Efficient Pagination
```elixir
# Cursor-based pagination for better performance
def get_pagila_page(cursor_id \\ nil, limit \\ 25) do
  base_query = Selecto.select(pagila_domain(), [:id, :name, :created_at])
  
  query = case cursor_id do
    nil -> base_query
    id -> Selecto.filter(base_query, :id, :gt, id)
  end
  
  query
  |> Selecto.order_by([{:id, :asc}])
  |> Selecto.limit(limit)
  |> Selecto.execute(MyApp.Repo)
end
```

### Batch Operations
```elixir
# Batch loading related data
def load_pagila_with_related(pagila_ids) do
  # Load main records
  pagilas = 
    Selecto.select(pagila_domain(), [:id, :name])
    |> Selecto.filter(:id, :in, pagila_ids)
    |> Selecto.execute(MyApp.Repo)
  
  # Load related data in batch
  related_data = 
    Selecto.select(related_domain(), [:pagila_id, :name])
    |> Selecto.filter(:pagila_id, :in, pagila_ids)
    |> Selecto.execute(MyApp.Repo)
    |> Enum.group_by(& &1.pagila_id)
  
  # Combine data
  Enum.map(pagilas, fn pagila ->
    Map.put(pagila, :related, Map.get(related_data, pagila.id, []))
  end)
end
```

## Error Handling Examples

### Safe Query Execution
```elixir
def safe_get_pagila(id) do
  try do
    result = 
      Selecto.select(pagila_domain(), [:id, :name])
      |> Selecto.filter(:id, :eq, id)
      |> Selecto.execute(MyApp.Repo)
    
    case result do
      [pagila] -> {:ok, pagila}
      [] -> {:error, :not_found}
      _ -> {:error, :multiple_results}
    end
  rescue
    e in [Ecto.Query.CastError] ->
      {:error, {:invalid_id, e.message}}
    e ->
      {:error, {:database_error, e.message}}
  end
end
```

### Validation Examples
```elixir
def validate_pagila_query(filters) do
  with :ok <- validate_required_fields(filters),
       :ok <- validate_filter_values(filters),
       :ok <- validate_query_complexity(filters) do
    build_pagila_query(filters)
  end
end

defp validate_required_fields(filters) do
  required = [:status]
  missing = required -- Map.keys(filters)
  
  case missing do
    [] -> :ok
    _ -> {:error, {:missing_fields, missing}}
  end
end
```

## Testing Examples

### Unit Tests for Domain Queries
```elixir
defmodule MyApp.PagilaQueriesTest do
  use MyApp.DataCase
  
  describe "pagila domain queries" do
    test "basic selection works" do
      pagila = insert(:pagila)
      
      result = 
        Selecto.select(pagila_domain(), [:id, :name])
        |> Selecto.filter(:id, :eq, pagila.id)
        |> Selecto.execute(MyApp.Repo)
      
      assert [found_pagila] = result
      assert found_pagila.id == pagila.id
      assert found_pagila.name == pagila.name
    end
    
    test "filtering by multiple criteria" do
      matching_pagila = insert(:pagila, status: "active", priority: "high")
      _non_matching = insert(:pagila, status: "inactive", priority: "high")
      
      result = 
        Selecto.select(pagila_domain(), [:id])
        |> Selecto.filter(:status, :eq, "active")
        |> Selecto.filter(:priority, :eq, "high")
        |> Selecto.execute(MyApp.Repo)
      
      assert length(result) == 1
      assert hd(result).id == matching_pagila.id
    end
  end
end
```

## Common Patterns and Recipes

### Search Functionality
```elixir
def search_pagilas(search_term, options \\ []) do
  limit = Keyword.get(options, :limit, 50)
  fields = Keyword.get(options, :fields, [:id, :name])
  
  Selecto.select(pagila_domain(), fields)
  |> add_search_filters(search_term)
  |> Selecto.order_by([{:name, :asc}])
  |> Selecto.limit(limit)
  |> Selecto.execute(MyApp.Repo)
end

defp add_search_filters(query, search_term) when is_binary(search_term) do
  search_pattern = "%#{search_term}%"
  
  Selecto.filter_group(query, :or, [
    {:name, :ilike, search_pattern},
    {:description, :ilike, search_pattern}
  ])
end
defp add_search_filters(query, _), do: query
```

### Dashboard Widgets
```elixir
def pagila_dashboard_data do
  %{
    total_count: get_total_pagila_count(),
    recent_pagilas: get_recent_pagilas(5),
    status_breakdown: get_pagila_status_breakdown(),
    trend_data: get_pagila_trend_data(30)
  }
end

defp get_total_pagila_count do
  Selecto.select(pagila_domain(), [:count])
  |> Selecto.aggregate(:count, :id)
  |> Selecto.execute(MyApp.Repo)
  |> hd()
  |> Map.get(:count)
end

defp get_recent_pagilas(limit) do
  Selecto.select(pagila_domain(), [:id, :name, :created_at])
  |> Selecto.order_by([{:created_at, :desc}])
  |> Selecto.limit(limit)
  |> Selecto.execute(MyApp.Repo)
end
```

## Best Practices Summary

1. **Always use proper error handling** around database operations
2. **Limit result sets** to avoid memory issues
3. **Use indexes** for frequently filtered and ordered fields
4. **Test with realistic data volumes** to catch performance issues early
5. **Batch related queries** instead of N+1 query patterns
6. **Use appropriate field selection** - don't select unnecessary data
7. **Monitor query performance** in production environments

For more detailed performance guidance, see the 
[Performance Guide](pagila_performance.md).
