# SelectoAsh Integration Plan

## Overview

**SelectoAsh** will act as a bridge between Ash Framework resources and Selecto's query building/visualization capabilities. It will leverage Ash's declarative resource definitions to automatically generate Selecto domain configurations.

## Core Architecture

```elixir
defmodule SelectoAsh do
  @moduledoc """
  Integration layer between Ash Framework resources and Selecto query builder.
  Automatically derives Selecto domain configurations from Ash resources.
  """
end
```

## 1. Resource Introspection Layer

**`SelectoAsh.ResourceIntrospector`**
- Analyze Ash resources to extract attributes, relationships, and actions
- Map Ash data types to Selecto column types  
- Extract validation rules and authorization policies
- Generate relationship mappings for joins

```elixir
defmodule SelectoAsh.ResourceIntrospector do
  def extract_domain_config(resource) do
    %{
      attributes: extract_attributes(resource),
      relationships: extract_relationships(resource), 
      actions: extract_actions(resource),
      policies: extract_policies(resource)
    }
  end
end
```

## 2. Domain Configuration Generator  

**`SelectoAsh.DomainGenerator`**
- Convert Ash resource definitions into Selecto domain configurations
- Auto-generate filters based on Ash attribute types and constraints
- Create custom columns from computed attributes and aggregates
- Map Ash relationships to Selecto join configurations

```elixir
defmodule SelectoAsh.DomainGenerator do
  def generate_selecto_domain(ash_resource) do
    config = ResourceIntrospector.extract_domain_config(ash_resource)
    
    %SelectoDomain{
      name: resource_name(ash_resource),
      schema: map_schema(config.attributes),
      filters: generate_filters(config.attributes),
      joins: generate_joins(config.relationships),
      custom_columns: generate_custom_columns(config)
    }
  end
end
```

## 3. Query Translation Layer

**`SelectoAsh.QueryTranslator`**
- Translate Selecto queries into Ash queries using `Ash.Query`
- Handle authorization through Ash policies automatically
- Convert Selecto filters to Ash filter expressions
- Map Selecto aggregations to Ash aggregates

```elixir
defmodule SelectoAsh.QueryTranslator do
  def translate_to_ash_query(selecto_query, ash_resource) do
    ash_resource
    |> Ash.Query.for_read(:read)
    |> apply_selecto_filters(selecto_query.filters)
    |> apply_selecto_sorts(selecto_query.sorts)
    |> apply_selecto_aggregates(selecto_query.aggregates)
  end
end
```

## 4. Data Access Layer

**`SelectoAsh.DataProvider`**  
- Execute translated Ash queries using the appropriate API
- Handle pagination and streaming for large datasets
- Cache query results when appropriate
- Provide real-time updates via PubSub when resources change

```elixir
defmodule SelectoAsh.DataProvider do
  def execute_query(ash_query, api) do
    case Ash.read(ash_query, api: api) do
      {:ok, results} -> format_for_selecto(results)
      {:error, error} -> {:error, error}
    end
  end
end
```

## 5. Domain Configuration Mapping

### Data Type Mapping
```elixir
defmodule SelectoAsh.TypeMapper do
  # Ash -> Selecto type mappings
  @type_mappings %{
    # Primitives
    :string => :string,
    :integer => :integer, 
    :decimal => :decimal,
    :boolean => :boolean,
    :date => :date,
    :datetime => :datetime,
    :uuid => :uuid,
    
    # Complex types
    {:array, inner} => {:array, map_type(inner)},
    :map => :json,
    :atom => :enum,
    
    # Custom Ash types
    Ash.Type.CiString => :string,
    Ash.Type.Union => :variant
  }
end
```

### Relationship Mapping
```elixir
defmodule SelectoAsh.RelationshipMapper do
  def map_ash_relationship(relationship) do
    %{
      type: map_relationship_type(relationship.type),
      source_attribute: relationship.source_attribute,
      destination_attribute: relationship.destination_attribute,
      destination_resource: relationship.destination,
      cardinality: relationship.cardinality
    }
  end
end
```

### Filter Generation
```elixir
defmodule SelectoAsh.FilterGenerator do
  def generate_filters(attributes) do
    Enum.flat_map(attributes, fn {name, config} ->
      base_filters = generate_base_filters(name, config.type)
      constraint_filters = generate_constraint_filters(name, config.constraints)
      base_filters ++ constraint_filters
    end)
  end
end
```

## 6. Query Translation Layer

### Filter Translation
```elixir
defmodule SelectoAsh.FilterTranslator do
  def translate_filter({field, operator, value}, resource) do
    case operator do
      :eq -> Ash.Query.filter(^ref(field) == ^value)
      :gt -> Ash.Query.filter(^ref(field) > ^value) 
      :contains -> Ash.Query.filter(contains(^ref(field), ^value))
      :in -> Ash.Query.filter(^ref(field) in ^value)
      :is_null -> Ash.Query.filter(is_nil(^ref(field)))
      # Handle relationship filters
      {:relationship, rel_name, rel_filter} ->
        translate_relationship_filter(rel_name, rel_filter)
    end
  end
end
```

### Aggregate Translation  
```elixir
defmodule SelectoAsh.AggregateTranslator do
  def translate_aggregate(selecto_aggregate, ash_resource) do
    case selecto_aggregate.function do
      :count -> 
        %{type: :count, name: selecto_aggregate.alias}
      :sum ->
        %{type: :sum, field: selecto_aggregate.field, name: selecto_aggregate.alias}
      :avg ->
        %{type: :avg, field: selecto_aggregate.field, name: selecto_aggregate.alias}
      :group_concat ->
        %{type: :list, field: selecto_aggregate.field, name: selecto_aggregate.alias}
    end
  end
end
```

### Authorization Integration
```elixir  
defmodule SelectoAsh.AuthorizationHandler do
  def apply_user_context(ash_query, user) do
    Ash.Query.set_context(ash_query, %{current_user: user})
  end
  
  def check_field_access(field, resource, user) do
    # Use Ash policies to check if user can access specific fields
    Ash.can?(%{resource: resource, action: :read}, user, 
             filter: [fields: [field]])
  end
end
```

## 7. LiveView Component Integration

### SelectoComponents Integration
```elixir
defmodule SelectoAsh.Components do
  use Phoenix.Component
  
  def ash_selecto_form(assigns) do
    ~H"""
    <.selecto_form 
      id={@id}
      domain={generate_domain_from_resource(@ash_resource)}
      query_provider={&SelectoAsh.DataProvider.execute_query/2}
      user_context={@current_user}
      api={@ash_api}
    />
    """
  end
  
  defp generate_domain_from_resource(resource) do
    SelectoAsh.DomainGenerator.generate_selecto_domain(resource)
  end
end
```

### Mix Tasks for Code Generation
```elixir
defmodule Mix.Tasks.SelectoAsh.Gen.Domain do
  def run([resource_name, api_name]) do
    resource = Module.concat([api_name, resource_name])
    domain_config = SelectoAsh.DomainGenerator.generate_selecto_domain(resource)
    
    # Generate domain file
    File.write!("lib/#{app_name()}/domains/#{resource_name}_domain.ex", 
                domain_template(resource_name, domain_config))
  end
end
```

## 8. Real-time Integration

### PubSub Integration
```elixir
defmodule SelectoAsh.RealtimeHandler do
  def subscribe_to_resource_changes(resource, user) do
    topic = "ash_resource:#{resource}"
    Phoenix.PubSub.subscribe(MyApp.PubSub, topic)
  end
  
  def handle_resource_change(resource, action, record) do
    # Broadcast to subscribed SelectoComponents
    Phoenix.PubSub.broadcast(MyApp.PubSub, 
      "ash_resource:#{resource}", 
      {:resource_changed, action, record})
  end
end
```

## 9. Usage Examples

### Basic Integration
```elixir
# In your LiveView
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  alias SelectoAsh.Components
  
  def render(assigns) do
    ~H"""
    <.ash_selecto_form 
      id="users-explorer"
      ash_resource={MyApp.Users.User}
      ash_api={MyApp.Users}
      current_user={@current_user}
    />
    """
  end
end
```

### Advanced Configuration
```elixir
defmodule MyApp.Domains.UserDomain do
  use SelectoAsh.Domain, 
    resource: MyApp.Users.User,
    api: MyApp.Users
    
  # Override specific configurations
  custom_filter "active_users", fn query ->
    Ash.Query.filter(query, is_nil(deleted_at))
  end
  
  custom_column "full_name", type: :string do
    fn record -> "#{record.first_name} #{record.last_name}" end
  end
end
```

## Implementation Plan

### Key Benefits

1. **Zero Configuration**: Automatically generate Selecto domains from existing Ash resources
2. **Authorization-First**: Leverage Ash policies for field-level and row-level security  
3. **Type Safety**: Full compile-time type checking between Ash and Selecto
4. **Real-time**: Built-in PubSub integration for live data updates
5. **Extensible**: Override and customize generated configurations

### Implementation Phases

**Phase 1: Core Integration**
- Resource introspection and domain generation
- Basic query translation (filters, sorts, pagination)
- Simple LiveView component integration

**Phase 2: Advanced Features** 
- Complex relationship handling and joins
- Aggregate and computed field support
- Authorization policy integration
- Custom filter and column definitions

**Phase 3: Developer Experience**
- Mix tasks for code generation
- Development tooling and debugging
- Comprehensive documentation and guides
- Real-time updates and PubSub integration

## Technical Considerations

### Ash Framework Integration Points

1. **Resource Definition Analysis**
   - Use `Ash.Resource.Info` to extract resource metadata
   - Parse attribute definitions, types, and constraints
   - Extract relationship configurations and cardinalities
   - Analyze action definitions and authorization policies

2. **Query Building**
   - Leverage `Ash.Query` for building type-safe queries
   - Use `Ash.Filter` for complex filtering logic
   - Implement `Ash.Sort` for ordering and pagination
   - Support `Ash.Aggregate` for statistical operations

3. **Authorization Integration**
   - Respect Ash policies for field and record access
   - Use actor context for user-based authorization
   - Support tenant-based multi-tenancy patterns
   - Handle authorization errors gracefully in UI

4. **Data Type Handling**
   - Map Ash types to appropriate Selecto column types
   - Handle custom Ash types with fallback strategies
   - Support union types and embedded resources
   - Manage temporal data with proper time zone handling

### Performance Considerations

1. **Query Optimization**
   - Use Ash's built-in query optimization
   - Implement intelligent eager loading for relationships
   - Support cursor-based pagination for large datasets
   - Cache domain configurations to avoid repeated introspection

2. **Real-time Updates**
   - Leverage Ash's built-in PubSub notifications
   - Implement selective updates to minimize network traffic
   - Support subscription filtering based on user permissions
   - Handle connection failures and automatic reconnection

### Error Handling

1. **Query Translation Errors**
   - Provide clear error messages for unsupported operations
   - Graceful degradation when features aren't available
   - Validation of Selecto queries before Ash translation
   - User-friendly error reporting in the UI

2. **Authorization Failures**
   - Handle unauthorized field access gracefully
   - Provide meaningful feedback for permission issues
   - Support partial results when some fields are restricted
   - Log security violations for audit purposes

This comprehensive plan provides a solid foundation for integrating Ash Framework with Selecto, creating a powerful and type-safe data exploration and visualization platform.