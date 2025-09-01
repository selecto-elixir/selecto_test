# Parameterized Joins Guide

## Overview

Parameterized joins in Selecto enable dynamic, flexible join configurations that adapt based on runtime parameters, domain structure, and query context. This advanced feature allows for reusable join patterns, conditional joins, and sophisticated multi-table relationships.

## Table of Contents

1. [Basic Parameterized Joins](#basic-parameterized-joins)
2. [Dynamic Join Conditions](#dynamic-join-conditions)
3. [Conditional Joins](#conditional-joins)
4. [Multi-Path Joins](#multi-path-joins)
5. [Join Templates](#join-templates)
6. [Domain-Aware Joins](#domain-aware-joins)
7. [Advanced Patterns](#advanced-patterns)
8. [Performance Optimization](#performance-optimization)

## Basic Parameterized Joins

### Simple Parameter Substitution

```elixir
# Basic parameterized join
defmodule JoinHelpers do
  def join_with_filters(selecto, table, filters) do
    join_conditions = Enum.map(filters, fn {field, value} ->
      "#{table}.#{field} = #{value}"
    end) |> Enum.join(" AND ")
    
    selecto
    |> Selecto.join(:inner, table, on: join_conditions)
  end
end

# Usage
selecto
|> JoinHelpers.join_with_filters("orders", %{
    "customer_id" => "customers.id",
    "status" => "'completed'"
  })

# Dynamic join type
def flexible_join(selecto, join_type, table, conditions) do
  selecto
  |> Selecto.join(join_type, table, on: conditions)
end

selecto
|> flexible_join(:left, "payments", "orders.id = payments.order_id")
|> flexible_join(:inner, "customers", "orders.customer_id = customers.id")
```

### Join with Runtime Parameters

```elixir
# Join with user-provided parameters
def build_report_query(selecto, %{include_payments: include_payments, include_items: include_items}) do
  selecto
  |> maybe_join_payments(include_payments)
  |> maybe_join_items(include_items)
end

defp maybe_join_payments(selecto, true) do
  selecto
  |> Selecto.join(:left, "payments", on: "orders.id = payments.order_id")
  |> Selecto.select_merge([
      {:sum, "payments.amount", as: "total_paid"},
      {:count, "payments.id", as: "payment_count"}
    ])
end
defp maybe_join_payments(selecto, false), do: selecto

defp maybe_join_items(selecto, true) do
  selecto
  |> Selecto.join(:left, "order_items", on: "orders.id = order_items.order_id")
  |> Selecto.select_merge([{:count, "order_items.id", as: "item_count"}])
end
defp maybe_join_items(selecto, false), do: selecto
```

## Dynamic Join Conditions

### Building Join Conditions Dynamically

```elixir
defmodule DynamicJoins do
  # Join with dynamic field mapping
  def join_with_mapping(selecto, source_table, target_table, field_map) do
    conditions = field_map
    |> Enum.map(fn {source_field, target_field} ->
      "#{source_table}.#{source_field} = #{target_table}.#{target_field}"
    end)
    |> Enum.join(" AND ")
    
    selecto
    |> Selecto.join(:inner, target_table, on: conditions)
  end
  
  # Join with complex conditions
  def join_with_conditions(selecto, table, conditions) do
    join_clause = build_join_clause(conditions)
    
    selecto
    |> Selecto.join(:inner, table, on: join_clause)
  end
  
  defp build_join_clause(conditions) do
    Enum.map(conditions, fn
      {:eq, field1, field2} -> 
        "#{field1} = #{field2}"
      {:gt, field1, field2} -> 
        "#{field1} > #{field2}"
      {:between, field, min, max} ->
        "#{field} BETWEEN #{min} AND #{max}"
      {:in, field, values} ->
        values_str = Enum.join(values, ", ")
        "#{field} IN (#{values_str})"
      {:custom, sql} ->
        sql
    end)
    |> Enum.join(" AND ")
  end
end

# Usage
selecto
|> DynamicJoins.join_with_mapping("orders", "customers", %{
    "customer_id" => "id",
    "billing_country" => "country"
  })
|> DynamicJoins.join_with_conditions("payments", [
    {:eq, "orders.id", "payments.order_id"},
    {:gt, "payments.amount", "0"},
    {:in, "payments.status", ["'completed'", "'pending'"]}
  ])
```

## Conditional Joins

### Context-Based Joins

```elixir
defmodule ConditionalJoins do
  def apply_role_based_joins(selecto, user_role) do
    case user_role do
      :admin ->
        selecto
        |> Selecto.join(:left, "audit_logs", on: "orders.id = audit_logs.order_id")
        |> Selecto.join(:left, "internal_notes", on: "orders.id = internal_notes.order_id")
        
      :manager ->
        selecto
        |> Selecto.join(:left, "team_assignments", on: "orders.id = team_assignments.order_id")
        
      :customer ->
        selecto
        |> Selecto.join(:inner, "customer_accessible", on: "orders.id = customer_accessible.order_id")
        
      _ ->
        selecto
    end
  end
  
  def apply_time_based_joins(selecto, time_range) do
    case time_range do
      :current ->
        selecto
        |> Selecto.join(:inner, "current_inventory", on: "products.id = current_inventory.product_id")
        
      :historical ->
        selecto
        |> Selecto.join(:inner, "inventory_history", 
            on: "products.id = inventory_history.product_id AND inventory_history.date >= '2024-01-01'")
        
      :forecast ->
        selecto
        |> Selecto.join(:left, "demand_forecast", on: "products.id = demand_forecast.product_id")
    end
  end
end
```

### Feature-Flag Based Joins

```elixir
defmodule FeatureFlagJoins do
  def build_query(selecto, feature_flags) do
    selecto
    |> maybe_join(:recommendations, feature_flags[:enable_recommendations])
    |> maybe_join(:reviews, feature_flags[:enable_reviews])
    |> maybe_join(:social_proof, feature_flags[:enable_social])
  end
  
  defp maybe_join(selecto, :recommendations, true) do
    selecto
    |> Selecto.join(:left, 
        "ml_recommendations", 
        on: "products.id = ml_recommendations.product_id AND ml_recommendations.score > 0.7")
  end
  
  defp maybe_join(selecto, :reviews, true) do
    selecto
    |> Selecto.join(:left,
        "(SELECT product_id, AVG(rating) as avg_rating, COUNT(*) as review_count 
          FROM reviews GROUP BY product_id) AS review_stats",
        on: "products.id = review_stats.product_id")
  end
  
  defp maybe_join(selecto, _, false), do: selecto
  defp maybe_join(selecto, _, nil), do: selecto
end
```

## Multi-Path Joins

### Alternative Join Paths

```elixir
defmodule MultiPathJoins do
  # Choose optimal join path based on data characteristics
  def smart_join_customers_orders(selecto, optimization_hint) do
    case optimization_hint do
      :via_recent ->
        # Join through recent orders index
        selecto
        |> Selecto.join(:inner,
            "(SELECT * FROM orders WHERE created_at > CURRENT_DATE - INTERVAL '30 days') AS recent_orders",
            on: "customers.id = recent_orders.customer_id")
            
      :via_high_value ->
        # Join through high-value orders
        selecto
        |> Selecto.join(:inner,
            "(SELECT * FROM orders WHERE total > 1000) AS high_value_orders",
            on: "customers.id = high_value_orders.customer_id")
            
      :via_indexed ->
        # Use indexed join path
        selecto
        |> Selecto.join(:inner,
            "order_customer_index",
            on: "customers.id = order_customer_index.customer_id")
        |> Selecto.join(:inner,
            "orders",
            on: "order_customer_index.order_id = orders.id")
            
      _ ->
        # Standard join
        selecto
        |> Selecto.join(:inner, "orders", on: "customers.id = orders.customer_id")
    end
  end
  
  # Multiple paths to same data
  def join_through_best_path(selecto, target_table, available_paths) do
    best_path = select_best_path(target_table, available_paths)
    apply_path_joins(selecto, best_path)
  end
  
  defp select_best_path(target, paths) do
    # Logic to choose optimal path based on statistics, indexes, etc.
    Enum.find(paths, fn path -> 
      path.estimated_cost == Enum.min_by(paths, & &1.estimated_cost).estimated_cost
    end)
  end
end
```

## Join Templates

### Reusable Join Patterns

```elixir
defmodule JoinTemplates do
  @doc """
  Standard e-commerce joins template
  """
  def ecommerce_joins(selecto, opts \\ []) do
    selecto
    |> join_customers(opts[:include_customers])
    |> join_products(opts[:include_products])
    |> join_inventory(opts[:include_inventory])
    |> join_shipping(opts[:include_shipping])
  end
  
  @doc """
  Time-series joins template
  """
  def time_series_joins(selecto, %{granularity: gran, range: range}) do
    selecto
    |> join_time_dimension(gran)
    |> join_metrics_table(range)
    |> join_aggregates(gran)
  end
  
  @doc """
  Hierarchical joins template
  """
  def hierarchical_joins(selecto, %{max_depth: depth, direction: dir}) do
    case dir do
      :up -> build_ancestor_joins(selecto, depth)
      :down -> build_descendant_joins(selecto, depth)
      :both -> 
        selecto
        |> build_ancestor_joins(depth)
        |> build_descendant_joins(depth)
    end
  end
  
  defp build_ancestor_joins(selecto, 0), do: selecto
  defp build_ancestor_joins(selecto, depth) do
    alias = "parent_#{depth}"
    prev_alias = if depth == 1, do: "base", else: "parent_#{depth - 1}"
    
    selecto
    |> Selecto.join(:left, 
        "hierarchy AS #{alias}",
        on: "#{prev_alias}.parent_id = #{alias}.id")
    |> build_ancestor_joins(depth - 1)
  end
end
```

### Composable Join Modules

```elixir
defmodule ComposableJoins do
  defmodule UserJoins do
    def with_profile(selecto) do
      Selecto.join(selecto, :left, "user_profiles", 
        on: "users.id = user_profiles.user_id")
    end
    
    def with_preferences(selecto) do
      Selecto.join(selecto, :left, "user_preferences",
        on: "users.id = user_preferences.user_id")
    end
    
    def with_activity(selecto, days \\ 30) do
      Selecto.join(selecto, :left,
        "(SELECT user_id, COUNT(*) as activity_count 
          FROM user_activity 
          WHERE created_at > CURRENT_DATE - INTERVAL '#{days} days'
          GROUP BY user_id) AS activity",
        on: "users.id = activity.user_id")
    end
  end
  
  defmodule OrderJoins do
    def with_items(selecto) do
      Selecto.join(selecto, :left, "order_items",
        on: "orders.id = order_items.order_id")
    end
    
    def with_payments(selecto) do
      Selecto.join(selecto, :left, "payments",
        on: "orders.id = payments.order_id")
    end
    
    def with_fulfillment(selecto) do
      Selecto.join(selecto, :left, "fulfillment",
        on: "orders.id = fulfillment.order_id")
    end
  end
  
  # Compose joins from multiple modules
  def build_complete_query(selecto) do
    selecto
    |> UserJoins.with_profile()
    |> UserJoins.with_activity(90)
    |> OrderJoins.with_items()
    |> OrderJoins.with_payments()
  end
end
```

## Domain-Aware Joins

### Leveraging Domain Configuration

```elixir
defmodule DomainAwareJoins do
  def auto_join_related(selecto, domain, related_tables) do
    Enum.reduce(related_tables, selecto, fn table_name, acc ->
      join_config = get_join_config(domain, table_name)
      apply_domain_join(acc, join_config)
    end)
  end
  
  defp get_join_config(domain, table) do
    # Extract join configuration from domain
    case domain.joins[table] do
      %{via: junction_table, on: conditions} ->
        %{type: :many_to_many, junction: junction_table, conditions: conditions}
        
      %{on: conditions, type: join_type} ->
        %{type: join_type, conditions: conditions}
        
      _ ->
        infer_join_config(domain, table)
    end
  end
  
  defp apply_domain_join(selecto, %{type: :many_to_many, junction: junction, conditions: conditions}) do
    selecto
    |> Selecto.join(:inner, junction, on: build_junction_conditions(conditions))
    |> Selecto.join(:inner, target_table_from_junction(junction), 
        on: build_target_conditions(conditions))
  end
  
  defp apply_domain_join(selecto, %{type: join_type, conditions: conditions}) do
    Selecto.join(selecto, join_type, parse_table_from_conditions(conditions),
      on: conditions)
  end
end
```

### Smart Join Resolution

```elixir
defmodule SmartJoinResolver do
  @doc """
  Automatically determines and applies optimal joins based on 
  fields referenced in select/filter clauses
  """
  def resolve_required_joins(selecto, domain) do
    required_tables = extract_required_tables(selecto)
    join_graph = build_join_graph(domain)
    join_path = find_optimal_join_path(join_graph, required_tables)
    
    apply_join_path(selecto, join_path)
  end
  
  defp extract_required_tables(selecto) do
    # Analyze select and filter clauses to determine required tables
    fields = extract_fields_from_select(selecto) ++ extract_fields_from_filters(selecto)
    
    fields
    |> Enum.map(&parse_table_from_field/1)
    |> Enum.uniq()
  end
  
  defp build_join_graph(domain) do
    # Build graph of possible joins from domain configuration
    %{
      nodes: Map.keys(domain.schemas),
      edges: build_join_edges(domain.joins)
    }
  end
  
  defp find_optimal_join_path(graph, required_tables) do
    # Use graph algorithm to find minimal join path
    # connecting all required tables
    find_minimum_spanning_tree(graph, required_tables)
  end
end
```

## Advanced Patterns

### Polymorphic Joins

```elixir
defmodule PolymorphicJoins do
  def join_polymorphic(selecto, %{
    type_column: type_col,
    id_column: id_col,
    type_mappings: mappings
  }) do
    Enum.reduce(mappings, selecto, fn {type_value, table_name}, acc ->
      acc
      |> Selecto.join(:left,
          "#{table_name}",
          on: "#{type_col} = '#{type_value}' AND #{id_col} = #{table_name}.id")
    end)
  end
  
  # Usage for comments that can belong to posts, videos, or images
  def join_commentables(selecto) do
    join_polymorphic(selecto, %{
      type_column: "comments.commentable_type",
      id_column: "comments.commentable_id",
      type_mappings: %{
        "Post" => "posts",
        "Video" => "videos",
        "Image" => "images"
      }
    })
  end
end
```

### Self-Referential Parameterized Joins

```elixir
defmodule SelfJoins do
  def join_self_n_times(selecto, table, n, join_condition_fn) do
    Enum.reduce(1..n, selecto, fn i, acc ->
      alias_name = "#{table}_#{i}"
      prev_alias = if i == 1, do: table, else: "#{table}_#{i-1}"
      
      condition = join_condition_fn.(prev_alias, alias_name)
      
      acc
      |> Selecto.join(:left, "#{table} AS #{alias_name}", on: condition)
    end)
  end
  
  # Find friends of friends
  def friends_network(selecto, depth) do
    join_self_n_times(selecto, "friendships", depth, fn prev, curr ->
      "#{prev}.friend_id = #{curr}.user_id"
    end)
  end
end
```

### Dynamic Cross-Database Joins

```elixir
defmodule CrossDatabaseJoins do
  def join_across_databases(selecto, %{
    database: db,
    schema: schema,
    table: table,
    condition: condition
  }) do
    fully_qualified_table = "#{db}.#{schema}.#{table}"
    
    selecto
    |> Selecto.join(:left, fully_qualified_table, on: condition)
  end
  
  def federated_join(selecto, remote_config) do
    # Use foreign data wrapper for remote joins
    selecto
    |> Selecto.join(:left,
        "dblink('#{remote_config.connection_string}', 
                '#{remote_config.query}') AS remote_data(#{remote_config.columns})",
        on: remote_config.join_condition)
  end
end
```

## Performance Optimization

### Join Order Optimization

```elixir
defmodule JoinOptimizer do
  def optimize_join_order(selecto, statistics) do
    joins = extract_joins(selecto)
    optimal_order = calculate_optimal_order(joins, statistics)
    rebuild_with_optimal_order(selecto, optimal_order)
  end
  
  defp calculate_optimal_order(joins, stats) do
    # Use cardinality estimates to determine optimal join order
    joins
    |> Enum.map(fn join ->
      %{
        join: join,
        selectivity: estimate_selectivity(join, stats),
        cardinality: estimate_cardinality(join, stats)
      }
    end)
    |> Enum.sort_by(& &1.selectivity)  # Most selective first
    |> Enum.map(& &1.join)
  end
end
```

### Lazy Join Loading

```elixir
defmodule LazyJoins do
  def prepare_lazy_joins(selecto, available_joins) do
    %{
      base_query: selecto,
      available_joins: available_joins,
      applied_joins: []
    }
  end
  
  def maybe_apply_join(lazy_query, join_name) do
    if join_name in lazy_query.applied_joins do
      lazy_query
    else
      join_config = lazy_query.available_joins[join_name]
      
      updated_query = apply_join(lazy_query.base_query, join_config)
      
      %{lazy_query | 
        base_query: updated_query,
        applied_joins: [join_name | lazy_query.applied_joins]}
    end
  end
end
```

## Best Practices

1. **Parameter Validation**: Always validate join parameters to prevent SQL injection
2. **Type Safety**: Use atoms for join types, not strings
3. **Lazy Loading**: Only apply joins when needed
4. **Index Awareness**: Ensure join columns are properly indexed
5. **Statistics**: Keep table statistics updated for optimizer
6. **Testing**: Test parameterized joins with various input combinations

## Common Use Cases

### Multi-Tenant Joins

```elixir
defmodule MultiTenantJoins do
  def scoped_joins(selecto, tenant_id) do
    selecto
    |> Selecto.join(:inner, "customers", 
        on: "orders.customer_id = customers.id AND customers.tenant_id = #{tenant_id}")
    |> Selecto.join(:inner, "products",
        on: "order_items.product_id = products.id AND products.tenant_id = #{tenant_id}")
  end
end
```

### Report Generation

```elixir
defmodule ReportJoins do
  def build_report_joins(selecto, report_config) do
    selecto
    |> apply_dimension_joins(report_config.dimensions)
    |> apply_metric_joins(report_config.metrics)
    |> apply_filter_joins(report_config.filters)
  end
end
```

## See Also

- [LATERAL Joins Guide](./lateral-joins.md)
- [Subqueries and Subfilters Guide](./subqueries-subfilters.md)
- [Domain Configuration Guide](../domain-configuration.md)
- [Performance Tuning Guide](./performance.md)