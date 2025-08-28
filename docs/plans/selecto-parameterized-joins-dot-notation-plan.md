# Selecto Parameterized Joins and Dot Notation Plan

## Overview
This plan outlines the enhancement of Selecto's column naming convention from `table[field]` to `table.field` and introduces parameterized joins for dynamic table relationships. The new system enables join parameters like `join('flags', 101)` and column references like `'flags[101].value'` with automatic join inference.

## Current State Analysis

### Current Column Naming Convention
- **Format**: `table[field]` (e.g., `"posts[title]"`, `"tags[name]"`)
- **Implementation**: Located in `/vendor/selecto/lib/selecto/schema/column.ex:63`
- **Join Dependencies**: Tracked via `requires_join` field in column configuration
- **Field Resolution**: Uses `Selecto.FieldResolver` for enhanced field lookup

### Current Join System
- **Static Joins**: Defined in domain configuration with fixed associations
- **Association-Based**: Uses Ecto associations for join relationships  
- **No Parameterization**: Cannot dynamically specify join parameters
- **SQL Generation**: Handled by `Selecto.Schema.Join` with various join types

### Example Current Usage
```elixir
# Current approach - static joins only
selecto
|> Selecto.select(["film[title]", "actor[name]"]) 
|> Selecto.filter([{"actor[first_name]", "John"}])
```

### Problem with Current System
The `film_flag` table structure reveals the need for parameterized joins:
```elixir
# film_flag.ex - Junction table with value field
schema "film_flag" do
  belongs_to :flag, SelectoTest.Store.Flag
  belongs_to :film, SelectoTest.Store.Film
  field :value, :string  # This field needs parameterization
end
```

**Current Limitation**: Cannot easily query "all films with flag_id=101 and their flag values" without complex manual joins.

## Proposed Solution: Parameterized Joins with Dot Notation

### New Column Naming Convention

#### Standard Fields (No Parameters)
```elixir
# Current: "actor[name]"
# New:     "actor.name"

selecto |> Selecto.select(["film.title", "actor.name"])
```

#### Parameterized Fields
```elixir
# New parameterized syntax
selecto 
|> Selecto.join("flags", 101)  # Join with parameter
|> Selecto.select(["film.title", "flags[101].value"])
```

#### Backward Compatibility
```elixir
# Support both formats during transition
selecto |> Selecto.select(["film.title", "actor[name]"])  # Still works
selecto |> Selecto.select(["film.title", "actor.name"])   # New format
```

### Join Parameter Syntax

#### Basic Parameterized Join
```elixir
# Join flags table with parameter 101
selecto = selecto |> Selecto.join("flags", 101)

# Multiple parameters for composite joins
selecto = selecto |> Selecto.join("film_flags", %{flag_id: 101, status: "active"})
```

#### Column References with Parameters
```elixir
# Reference parameterized join columns
selecto |> Selecto.select(["flags[101].value", "flags[101].created_at"])

# Filter on parameterized columns  
selecto |> Selecto.filter([{"flags[101].value", "important"}])

# Mix parameterized and standard columns
selecto |> Selecto.select(["film.title", "flags[101].value", "actor.name"])
```

#### Auto-Join Inference
```elixir
# System infers join needed when column is referenced
selecto 
|> Selecto.select(["film.title", "flags[101].value"])  # Auto-adds join for flags[101]
|> Selecto.filter([{"flags[102].value", "critical"}])  # Auto-adds join for flags[102]

# Strict mode - raises error if join not explicitly declared
selecto = Selecto.configure(domain, postgrex_opts, strict_joins: true)
selecto |> Selecto.select(["flags[101].value"])  # Raises: JoinNotExplicitlyDeclaredError
```

## Implementation Architecture

### Phase 1: Core Infrastructure

#### 1.1 Parameter-Aware Column Parsing
```elixir
defmodule Selecto.Parser.ColumnReference do
  @doc """
  Parse column references supporting both dot and bracket notation with parameters.
  
  Examples:
    "film.title" -> %{table: "film", field: "title", params: nil}
    "film[title]" -> %{table: "film", field: "title", params: nil} # Backward compat
    "flags[101].value" -> %{table: "flags", field: "value", params: [101]}
    "film_flags[flag_id: 101, status: 'active'].value" -> %{table: "film_flags", field: "value", params: [flag_id: 101, status: "active"]}
  """
  def parse(column_reference) when is_binary(column_reference) do
    case parse_with_params(column_reference) do
      {:ok, result} -> result
      {:error, reason} -> raise Selecto.ColumnParseError, reason
    end
  end

  defp parse_with_params(column_ref) do
    # Support multiple formats:
    # 1. "table.field" (new dot notation)
    # 2. "table[field]" (legacy bracket notation) 
    # 3. "table[param].field" (parameterized dot notation)
    # 4. "table[param][field]" (parameterized bracket notation)
    
    cond do
      # Parameterized with dot notation: "flags[101].value"
      Regex.match?(~r/^(\w+)\[([^\]]+)\]\.(\w+)$/, column_ref) ->
        case Regex.run(~r/^(\w+)\[([^\]]+)\]\.(\w+)$/, column_ref) do
          [_, table, param_str, field] ->
            {:ok, %{
              table: table,
              field: field,
              params: parse_parameters(param_str),
              original: column_ref,
              format: :parameterized_dot
            }}
        end

      # Standard dot notation: "table.field"  
      Regex.match?(~r/^(\w+)\.(\w+)$/, column_ref) ->
        case Regex.run(~r/^(\w+)\.(\w+)$/, column_ref) do
          [_, table, field] ->
            {:ok, %{
              table: table,
              field: field,
              params: nil,
              original: column_ref,
              format: :dot
            }}
        end

      # Legacy bracket notation: "table[field]"
      Regex.match?(~r/^(\w+)\[(\w+)\]$/, column_ref) ->
        case Regex.run(~r/^(\w+)\[(\w+)\]$/, column_ref) do
          [_, table, field] ->
            {:ok, %{
              table: table,
              field: field,
              params: nil,
              original: column_ref,
              format: :bracket_legacy
            }}
        end

      true ->
        {:error, "Invalid column reference format: #{column_ref}"}
    end
  end

  defp parse_parameters(param_str) do
    # Handle various parameter formats:
    # "101" -> [101]
    # "101, 'active'" -> [101, "active"] 
    # "flag_id: 101, status: 'active'" -> [flag_id: 101, status: "active"]
    
    cond do
      # Simple integer parameter
      Regex.match?(~r/^\d+$/, param_str) ->
        [String.to_integer(param_str)]
      
      # Key-value parameters: "flag_id: 101, status: 'active'"
      String.contains?(param_str, ":") ->
        param_str
        |> String.split(",")
        |> Enum.map(&parse_key_value_param/1)
        
      # Multiple simple parameters: "101, 'active'"
      String.contains?(param_str, ",") ->
        param_str
        |> String.split(",")
        |> Enum.map(&parse_simple_param/1)
        
      true ->
        [parse_simple_param(param_str)]
    end
  end

  defp parse_key_value_param(param_str) do
    case String.split(String.trim(param_str), ":", limit: 2) do
      [key, value] ->
        {String.to_atom(String.trim(key)), parse_simple_param(value)}
      _ ->
        raise Selecto.ColumnParseError, "Invalid key-value parameter: #{param_str}"
    end
  end

  defp parse_simple_param(param_str) do
    param_str = String.trim(param_str)
    
    cond do
      # Integer
      Regex.match?(~r/^\d+$/, param_str) ->
        String.to_integer(param_str)
      
      # String with quotes
      Regex.match?(~r/^['"][^'"]*['"]$/, param_str) ->
        String.slice(param_str, 1..-2)  # Remove quotes
      
      # Atom
      Regex.match?(~r/^:\w+$/, param_str) ->
        String.to_atom(String.slice(param_str, 1..-1))
      
      true ->
        param_str  # Keep as string
    end
  end
end
```

#### 1.2 Enhanced Join Registry
```elixir
defmodule Selecto.JoinRegistry do
  @moduledoc """
  Registry for managing parameterized joins and their dependencies.
  """
  
  defstruct [:static_joins, :parameterized_joins, :auto_joins, :strict_mode]
  
  def new(opts \\ []) do
    %__MODULE__{
      static_joins: %{},
      parameterized_joins: %{},
      auto_joins: MapSet.new(),
      strict_mode: Keyword.get(opts, :strict_joins, false)
    }
  end
  
  @doc """
  Register a parameterized join.
  
  Examples:
    register_join(registry, "flags", [101])
    register_join(registry, "film_flags", [flag_id: 101, status: "active"])
  """
  def register_join(registry, table, params) do
    join_key = build_join_key(table, params)
    
    join_config = %{
      table: table,
      params: params,
      alias: join_key,
      sql_alias: generate_sql_alias(table, params),
      registered_at: DateTime.utc_now()
    }
    
    %{registry | parameterized_joins: Map.put(registry.parameterized_joins, join_key, join_config)}
  end
  
  @doc """
  Auto-register join from column reference if not in strict mode.
  """
  def maybe_auto_register_join(registry, %{table: table, params: params} = column_ref) when not is_nil(params) do
    join_key = build_join_key(table, params)
    
    cond do
      registry.strict_mode ->
        {:error, {:join_not_declared, join_key, column_ref}}
      
      Map.has_key?(registry.parameterized_joins, join_key) ->
        {:ok, registry}  # Join already exists
      
      true ->
        # Auto-register the join
        updated_registry = register_join(registry, table, params)
        updated_registry = %{updated_registry | auto_joins: MapSet.put(updated_registry.auto_joins, join_key)}
        {:ok, updated_registry}
    end
  end
  
  def maybe_auto_register_join(registry, _column_ref), do: {:ok, registry}
  
  def get_join(registry, table, params) do
    join_key = build_join_key(table, params)
    Map.get(registry.parameterized_joins, join_key)
  end
  
  def list_joins(registry) do
    Map.values(registry.parameterized_joins)
  end
  
  defp build_join_key(table, params) do
    param_suffix = case params do
      nil -> ""
      [] -> ""
      params when is_list(params) -> "[#{Enum.join(params, ",")}]"
    end
    
    "#{table}#{param_suffix}"
  end
  
  defp generate_sql_alias(table, params) do
    case params do
      nil -> table
      [] -> table
      [single_param] when is_integer(single_param) -> "#{table}_#{single_param}"
      params when is_list(params) ->
        param_hash = :crypto.hash(:md5, inspect(params)) |> Base.encode16(case: :lower) |> String.slice(0, 8)
        "#{table}_#{param_hash}"
    end
  end
end
```

### Phase 2: SQL Generation Enhancement

#### 2.1 Parameterized Join SQL Builder
```elixir
defmodule Selecto.Builder.ParameterizedJoin do
  @doc """
  Build SQL for parameterized joins based on join registry.
  """
  def build_parameterized_joins(selecto, registry) do
    registry
    |> Selecto.JoinRegistry.list_joins()
    |> Enum.map(&build_join_sql(&1, selecto))
    |> Enum.join(" ")
  end

  defp build_join_sql(join_config, selecto) do
    %{table: table, params: params, sql_alias: sql_alias} = join_config
    
    # Get domain configuration for this table
    case find_join_association(selecto, table) do
      {:ok, association, join_table_schema} ->
        build_association_join_sql(association, join_table_schema, params, sql_alias, selecto)
      
      {:error, :not_found} ->
        # Handle as direct table join
        build_direct_join_sql(table, params, sql_alias, selecto)
    end
  end

  defp build_association_join_sql(association, join_table_schema, params, sql_alias, selecto) do
    source_table = selecto.config.source_table
    source_alias = "t0"  # Main table alias
    
    base_join = """
    LEFT JOIN #{join_table_schema.source_table} AS #{sql_alias} 
    ON #{source_alias}.#{association.owner_key} = #{sql_alias}.#{association.related_key}
    """
    
    # Add parameter conditions
    case build_parameter_conditions(params, sql_alias) do
      "" -> base_join
      conditions -> base_join <> " AND " <> conditions
    end
  end

  defp build_direct_join_sql(table, params, sql_alias, selecto) do
    # For direct table joins, need to infer join conditions
    # This is more complex and may require configuration
    source_table = selecto.config.source_table
    source_alias = "t0"
    
    # Default assumption: table has a foreign key to source table
    foreign_key = infer_foreign_key(source_table)
    primary_key = selecto.config.primary_key
    
    base_join = """
    LEFT JOIN #{table} AS #{sql_alias} 
    ON #{source_alias}.#{primary_key} = #{sql_alias}.#{foreign_key}
    """
    
    # Add parameter conditions
    case build_parameter_conditions(params, sql_alias) do
      "" -> base_join
      conditions -> base_join <> " AND " <> conditions
    end
  end

  defp build_parameter_conditions(nil, _alias), do: ""
  defp build_parameter_conditions([], _alias), do: ""
  defp build_parameter_conditions([single_param] = _params, sql_alias) when is_integer(single_param) do
    # For simple integer parameter, assume it's an ID filter
    # This may need to be configurable per join type
    "#{sql_alias}.id = #{single_param}"
  end
  defp build_parameter_conditions(params, sql_alias) when is_list(params) do
    params
    |> Enum.map(fn
      {key, value} when is_atom(key) ->
        "#{sql_alias}.#{key} = #{format_sql_value(value)}"
      value ->
        "#{sql_alias}.id = #{format_sql_value(value)}"
    end)
    |> Enum.join(" AND ")
  end

  defp format_sql_value(value) when is_integer(value), do: to_string(value)
  defp format_sql_value(value) when is_binary(value), do: "'#{String.replace(value, "'", "''")}'"
  defp format_sql_value(value) when is_atom(value), do: "'#{value}'"
  defp format_sql_value(value), do: "'#{value}'"

  defp find_join_association(selecto, table) do
    # Look through domain schemas to find association for this table
    selecto.domain.schemas
    |> Enum.find_value(fn {_schema_key, schema} ->
      case schema.source_table do
        ^table -> {:ok, nil, schema}  # Direct schema match
        _ -> nil
      end
    end)
    |> case do
      nil ->
        # Look through associations
        find_association_by_table(selecto, table)
      result ->
        result
    end
  end

  defp find_association_by_table(selecto, table) do
    # Search through all associations to find one pointing to this table
    selecto.domain.source.associations
    |> Enum.find_value(fn {_assoc_key, association} ->
      case Map.get(selecto.domain.schemas, association.queryable) do
        %{source_table: ^table} = schema -> {:ok, association, schema}
        _ -> nil
      end
    end)
    |> case do
      nil -> {:error, :not_found}
      result -> result
    end
  end

  defp infer_foreign_key(source_table) do
    # Convention: table name + "_id"
    "#{String.trim_trailing(source_table, "s")}_id"
  end
end
```

#### 2.2 Enhanced Field Resolution
```elixir
defmodule Selecto.FieldResolver do
  # Extend existing field resolver to handle parameterized columns
  
  def resolve_field(selecto, field_reference) when is_binary(field_reference) do
    parsed_column = Selecto.Parser.ColumnReference.parse(field_reference)
    
    case parsed_column.params do
      nil ->
        # Standard field resolution
        resolve_standard_field(selecto, parsed_column)
        
      params ->
        # Parameterized field resolution
        resolve_parameterized_field(selecto, parsed_column, params)
    end
  end

  defp resolve_parameterized_field(selecto, parsed_column, params) do
    %{table: table, field: field} = parsed_column
    
    # Check if join is registered or can be auto-registered
    case Selecto.JoinRegistry.maybe_auto_register_join(selecto.join_registry, parsed_column) do
      {:ok, updated_registry} ->
        # Update selecto with new registry
        selecto = %{selecto | join_registry: updated_registry}
        
        # Get join configuration
        join_config = Selecto.JoinRegistry.get_join(updated_registry, table, params)
        
        build_parameterized_field_info(parsed_column, join_config)
        
      {:error, {:join_not_declared, join_key, _column_ref}} ->
        {:error, %Selecto.Error{
          type: :join_not_declared,
          message: "Join '#{join_key}' must be explicitly declared in strict mode",
          field: parsed_column.original,
          suggestions: ["Add: selecto |> Selecto.join(\"#{table}\", #{inspect(params)})"]
        }}
    end
  end

  defp build_parameterized_field_info(parsed_column, join_config) do
    %{table: table, field: field} = parsed_column
    %{sql_alias: sql_alias} = join_config
    
    {:ok, %{
      name: field,
      field: field,
      type: infer_field_type(field),  # May need schema lookup
      table: table,
      sql_alias: sql_alias,
      qualified_name: "#{sql_alias}.#{field}",
      alias: "#{table}_#{field}",
      source_join: sql_alias,
      is_parameterized: true,
      join_params: join_config.params,
      original_reference: parsed_column.original
    }}
  end

  defp resolve_standard_field(selecto, parsed_column) do
    # Delegate to existing field resolution logic
    # but update to use dot notation in qualified names
    %{table: table, field: field} = parsed_column
    
    case find_field_in_domain(selecto, table, field) do
      {:ok, field_info} ->
        # Convert bracket notation to dot notation in output
        updated_field_info = %{field_info | 
          qualified_name: String.replace(field_info.qualified_name, "[", ".") |> String.replace("]", ""),
          original_reference: parsed_column.original
        }
        {:ok, updated_field_info}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  # ... rest of existing field resolution logic
  defp find_field_in_domain(selecto, table, field) do
    # Existing implementation with updates for dot notation
    # This would integrate with current column configuration system
  end

  defp infer_field_type(field) do
    # Basic type inference - may need schema integration
    cond do
      String.ends_with?(field, "_id") -> :integer
      String.ends_with?(field, "_at") -> :utc_datetime
      field in ["created_at", "updated_at"] -> :utc_datetime
      field in ["id"] -> :integer
      true -> :string  # Default fallback
    end
  end
end
```

### Phase 3: API Integration

#### 3.1 Enhanced Selecto API
```elixir
defmodule Selecto do
  # Add to existing Selecto module

  @doc """
  Add a parameterized join to the query.
  
  Examples:
    # Simple parameter join
    selecto |> Selecto.join("flags", 101)
    
    # Multiple parameter join  
    selecto |> Selecto.join("film_flags", %{flag_id: 101, status: "active"})
    
    # With join options
    selecto |> Selecto.join("flags", 101, type: :inner, alias: "important_flags")
  """
  def join(selecto, table, params, opts \\ [])

  def join(selecto, table, params, opts) when is_binary(table) do
    # Ensure join registry exists
    registry = Map.get(selecto, :join_registry, Selecto.JoinRegistry.new())
    
    # Register the parameterized join
    updated_registry = Selecto.JoinRegistry.register_join(registry, table, params)
    
    # Update selecto with new registry
    %{selecto | join_registry: updated_registry}
  end

  # Extend existing select/2 to handle new column formats
  def select(selecto, fields) when is_list(fields) do
    # Process each field to handle parameterized references
    processed_fields = Enum.map(fields, &process_field_reference(selecto, &1))
    
    # Update join registry with any auto-discovered joins
    updated_selecto = update_join_registry_from_fields(selecto, processed_fields)
    
    # Continue with existing select logic
    put_in(updated_selecto.set.selected, Enum.uniq(updated_selecto.set.selected ++ processed_fields))
  end

  defp process_field_reference(selecto, field_ref) when is_binary(field_ref) do
    case Selecto.Parser.ColumnReference.parse(field_ref) do
      %{params: nil} = parsed ->
        # Standard field - convert to new format if needed
        case parsed.format do
          :bracket_legacy -> "#{parsed.table}.#{parsed.field}"  # Convert to dot notation
          _ -> field_ref  # Keep as is
        end
        
      %{params: params} = parsed when not is_nil(params) ->
        # Parameterized field - ensure join is registered
        registry = Map.get(selecto, :join_registry, Selecto.JoinRegistry.new())
        
        case Selecto.JoinRegistry.maybe_auto_register_join(registry, parsed) do
          {:ok, _updated_registry} -> field_ref  # Valid parameterized field
          {:error, {:join_not_declared, join_key, _}} ->
            raise Selecto.JoinNotDeclaredError, "Join '#{join_key}' must be explicitly declared. Use: selecto |> Selecto.join(\"#{parsed.table}\", #{inspect(params)})"
        end
    end
  end

  defp update_join_registry_from_fields(selecto, processed_fields) do
    # Update join registry based on processed fields
    # This handles auto-registration of joins discovered during field processing
    selecto  # Simplified - would contain actual registry update logic
  end

  # Extend configure/3 to support strict join mode
  def configure(domain, postgrex_opts, opts \\ []) do
    # Existing configuration logic...
    base_selecto = configure_existing(domain, postgrex_opts, opts)
    
    # Add join registry
    strict_joins = Keyword.get(opts, :strict_joins, false)
    join_registry = Selecto.JoinRegistry.new(strict_joins: strict_joins)
    
    Map.put(base_selecto, :join_registry, join_registry)
  end
  
  # ... existing functions remain unchanged
end
```

#### 3.2 SQL Generation Integration
```elixir
defmodule Selecto.Builder.Sql do
  # Extend existing SQL builder to handle parameterized joins

  def build(selecto, opts) do
    # Get parameterized joins SQL
    parameterized_joins_sql = case Map.get(selecto, :join_registry) do
      nil -> ""
      registry -> Selecto.Builder.ParameterizedJoin.build_parameterized_joins(selecto, registry)
    end
    
    # Build standard SQL components
    {base_sql, aliases, params} = build_existing_sql(selecto, opts)
    
    # Inject parameterized joins into the SQL
    enhanced_sql = inject_parameterized_joins(base_sql, parameterized_joins_sql)
    
    {enhanced_sql, aliases, params}
  end

  defp inject_parameterized_joins(base_sql, parameterized_joins_sql) do
    case parameterized_joins_sql do
      "" -> base_sql
      joins -> 
        # Find the position to inject joins (after FROM clause, before WHERE)
        String.replace(base_sql, ~r/(FROM\s+\w+\s+(?:AS\s+\w+\s+)?)/i, "\\1#{joins} ")
    end
  end

  # ... rest of existing SQL building logic
end
```

### Phase 4: Error Handling and Validation

#### 4.1 Enhanced Error Types
```elixir
defmodule Selecto.Error do
  # Add new error types for parameterized joins
  
  defexception [:type, :message, :field, :join, :params, :suggestions]

  def exception(opts) do
    type = Keyword.get(opts, :type, :unknown)
    message = build_message(type, opts)
    
    %__MODULE__{
      type: type,
      message: message,
      field: Keyword.get(opts, :field),
      join: Keyword.get(opts, :join),
      params: Keyword.get(opts, :params),
      suggestions: Keyword.get(opts, :suggestions, [])
    }
  end

  defp build_message(:join_not_declared, opts) do
    join = Keyword.get(opts, :join)
    field = Keyword.get(opts, :field)
    "Join '#{join}' must be explicitly declared before referencing field '#{field}'"
  end

  defp build_message(:column_parse_error, opts) do
    field = Keyword.get(opts, :field)
    "Invalid column reference format: '#{field}'"
  end

  defp build_message(:parameterized_join_not_found, opts) do
    join = Keyword.get(opts, :join)
    params = Keyword.get(opts, :params)
    "Parameterized join '#{join}' with parameters #{inspect(params)} not found in domain configuration"
  end

  defp build_message(type, opts) do
    # Fallback to existing error message building
    build_existing_message(type, opts)
  end
end

defmodule Selecto.JoinNotDeclaredError do
  defexception message: "Join not explicitly declared"
end

defmodule Selecto.ColumnParseError do
  defexception message: "Invalid column reference format"
end
```

#### 4.2 Validation System
```elixir
defmodule Selecto.Validator.ParameterizedJoins do
  @doc """
  Validate parameterized joins against domain configuration.
  """
  def validate_joins(selecto) do
    case Map.get(selecto, :join_registry) do
      nil -> {:ok, selecto}
      registry -> validate_registry_joins(selecto, registry)
    end
  end

  defp validate_registry_joins(selecto, registry) do
    registry
    |> Selecto.JoinRegistry.list_joins()
    |> Enum.reduce_while({:ok, []}, fn join_config, {:ok, acc} ->
      case validate_single_join(selecto, join_config) do
        :ok -> {:cont, {:ok, [join_config | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, _valid_joins} -> {:ok, selecto}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_single_join(selecto, join_config) do
    %{table: table, params: params} = join_config
    
    # Check if table exists in domain or can be inferred
    case find_table_in_domain(selecto, table) do
      {:ok, _schema} -> validate_join_parameters(join_config)
      {:error, :not_found} -> 
        {:error, %Selecto.Error{
          type: :table_not_found,
          message: "Table '#{table}' not found in domain configuration",
          join: table,
          params: params,
          suggestions: get_table_suggestions(selecto, table)
        }}
    end
  end

  defp validate_join_parameters(join_config) do
    # Validate that parameters are in acceptable formats
    %{params: params} = join_config
    
    case params do
      nil -> :ok
      [] -> :ok
      params when is_list(params) -> validate_parameter_list(params)
    end
  end

  defp validate_parameter_list(params) do
    Enum.reduce_while(params, :ok, fn param, :ok ->
      case validate_single_parameter(param) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_single_parameter(param) when is_integer(param), do: :ok
  defp validate_single_parameter(param) when is_binary(param), do: :ok
  defp validate_single_parameter(param) when is_atom(param), do: :ok
  defp validate_single_parameter({key, value}) when is_atom(key) do
    validate_single_parameter(value)
  end
  defp validate_single_parameter(param) do
    {:error, %Selecto.Error{
      type: :invalid_join_parameter,
      message: "Invalid join parameter type: #{inspect(param)}. Must be integer, string, atom, or {key, value} tuple"
    }}
  end

  defp find_table_in_domain(selecto, table) do
    # Check if table exists in schemas
    selecto.domain.schemas
    |> Enum.find_value(fn {_key, schema} ->
      if schema.source_table == table do
        {:ok, schema}
      else
        nil
      end
    end)
    |> case do
      nil -> {:error, :not_found}
      result -> result
    end
  end

  defp get_table_suggestions(selecto, target_table) do
    # Get similar table names for suggestions
    all_tables = get_all_table_names(selecto)
    
    all_tables
    |> Enum.filter(&(String.jaro_distance(&1, target_table) > 0.6))
    |> Enum.sort_by(&String.jaro_distance(&1, target_table), :desc)
    |> Enum.take(3)
    |> Enum.map(&"Did you mean '#{&1}'?")
  end

  defp get_all_table_names(selecto) do
    selecto.domain.schemas
    |> Enum.map(fn {_key, schema} -> schema.source_table end)
    |> Enum.uniq()
  end
end
```

## Testing Strategy

### Unit Tests
```elixir
defmodule Selecto.Parser.ColumnReferenceTest do
  use ExUnit.Case
  
  describe "parse/1" do
    test "parses dot notation" do
      result = Selecto.Parser.ColumnReference.parse("film.title")
      assert result.table == "film"
      assert result.field == "title"
      assert result.params == nil
      assert result.format == :dot
    end
    
    test "parses legacy bracket notation" do
      result = Selecto.Parser.ColumnReference.parse("film[title]")
      assert result.table == "film"
      assert result.field == "title"
      assert result.params == nil
      assert result.format == :bracket_legacy
    end
    
    test "parses parameterized dot notation" do
      result = Selecto.Parser.ColumnReference.parse("flags[101].value")
      assert result.table == "flags"
      assert result.field == "value"
      assert result.params == [101]
      assert result.format == :parameterized_dot
    end
    
    test "parses complex parameterized notation" do
      result = Selecto.Parser.ColumnReference.parse("film_flags[flag_id: 101, status: 'active'].value")
      assert result.table == "film_flags"
      assert result.field == "value"
      assert result.params == [flag_id: 101, status: "active"]
    end
  end
end

defmodule Selecto.JoinRegistryTest do
  use ExUnit.Case
  
  describe "parameterized joins" do
    test "registers simple parameterized join" do
      registry = Selecto.JoinRegistry.new()
      updated = Selecto.JoinRegistry.register_join(registry, "flags", [101])
      
      join_config = Selecto.JoinRegistry.get_join(updated, "flags", [101])
      assert join_config.table == "flags"
      assert join_config.params == [101]
      assert join_config.sql_alias == "flags_101"
    end
    
    test "auto-registers joins when not in strict mode" do
      registry = Selecto.JoinRegistry.new(strict_joins: false)
      column_ref = %{table: "flags", field: "value", params: [101]}
      
      {:ok, updated} = Selecto.JoinRegistry.maybe_auto_register_join(registry, column_ref)
      
      join_config = Selecto.JoinRegistry.get_join(updated, "flags", [101])
      assert join_config != nil
      assert "flags[101]" in updated.auto_joins
    end
    
    test "rejects auto-registration in strict mode" do
      registry = Selecto.JoinRegistry.new(strict_joins: true)
      column_ref = %{table: "flags", field: "value", params: [101]}
      
      {:error, {:join_not_declared, join_key, _}} = 
        Selecto.JoinRegistry.maybe_auto_register_join(registry, column_ref)
      
      assert join_key == "flags[101]"
    end
  end
end
```

### Integration Tests
```elixir
defmodule Selecto.ParameterizedJoinsIntegrationTest do
  use ExUnit.Case
  
  setup do
    # Setup test database with film_flag table
    postgrex_opts = [
      hostname: "localhost",
      username: "postgres", 
      password: "postgres",
      database: "selecto_test"
    ]
    
    domain = %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :string}
        }
      },
      schemas: %{
        film_flag: %{
          source_table: "film_flag",
          primary_key: [:film_id, :flag_id],
          fields: [:film_id, :flag_id, :value],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            flag_id: %{type: :integer},
            value: %{type: :string}
          }
        }
      }
    }
    
    {:ok, selecto: Selecto.configure(domain, postgrex_opts)}
  end
  
  test "end-to-end parameterized join query", %{selecto: selecto} do
    # Test the complete flow: join -> select -> execute
    result_selecto = selecto
    |> Selecto.join("film_flag", [flag_id: 101])
    |> Selecto.select(["film.title", "film_flag[flag_id: 101].value"])
    |> Selecto.filter([{"film_flag[flag_id: 101].value", "important"}])
    
    {sql, params} = Selecto.to_sql(result_selecto)
    
    # Verify SQL contains parameterized join
    assert sql =~ "LEFT JOIN film_flag AS film_flag_"
    assert sql =~ "film_flag_.flag_id = 101"
    assert sql =~ "film_flag_.value = 'important'"
  end
  
  test "auto-join inference", %{selecto: selecto} do
    # Test that joins are automatically inferred from column references
    result_selecto = selecto
    |> Selecto.select(["film.title", "film_flag[flag_id: 101].value"])
    
    # Verify join was auto-registered
    assert Map.has_key?(result_selecto.join_registry.parameterized_joins, "film_flag[flag_id: 101]")
    
    {sql, _params} = Selecto.to_sql(result_selecto)
    assert sql =~ "LEFT JOIN film_flag"
  end
  
  test "strict mode prevents auto-joins", %{selecto: base_selecto} do
    selecto = %{base_selecto | join_registry: Selecto.JoinRegistry.new(strict_joins: true)}
    
    assert_raise Selecto.JoinNotDeclaredError, fn ->
      selecto |> Selecto.select(["film_flag[flag_id: 101].value"])
    end
  end
end
```

## Migration Strategy

### Phase A: Backward Compatibility (Weeks 1-2)
1. **Dual Format Support**
   - Support both `table[field]` and `table.field` formats
   - Automatic conversion in field resolution
   - No breaking changes to existing APIs

2. **Parameterized Join Infrastructure**
   - Implement core join registry and parsing
   - Add new `join/3` API method
   - Maintain existing join behavior

### Phase B: Feature Rollout (Weeks 3-4)
1. **Enhanced SQL Generation**
   - Integrate parameterized joins into SQL builder
   - Add validation and error handling
   - Comprehensive test coverage

2. **Documentation and Examples**
   - Update documentation with new syntax
   - Add migration guide for existing code
   - Create comprehensive examples

### Phase C: Adoption and Optimization (Weeks 5-6)
1. **Performance Optimization**
   - Optimize join registry performance
   - Implement join result caching
   - Monitor SQL generation overhead

2. **Advanced Features**
   - Complex parameter types (ranges, arrays)
   - Join condition customization
   - Integration with SelectoComponents

## Success Metrics

### Functionality
- **Column Reference Parsing**: 100% accuracy for all format types
- **Join Registration**: < 1ms overhead for join operations
- **SQL Generation**: Valid SQL for all parameterized join combinations
- **Backward Compatibility**: 100% existing code compatibility

### Performance
- **Query Performance**: < 5% overhead vs. static joins
- **Memory Usage**: < 10MB additional memory for join registry
- **Parse Time**: < 1ms for complex column references

### Developer Experience
- **Error Messages**: Clear, actionable error messages with suggestions
- **API Consistency**: Intuitive API that follows existing patterns
- **Documentation**: Complete coverage of all features and edge cases

## Future Enhancements

### Advanced Parameter Types
```elixir
# Range parameters
selecto |> Selecto.join("time_flags", date_range: ~D[2024-01-01]..~D[2024-12-31])
selecto |> Selecto.select(["time_flags[date_range: 2024-01-01..2024-12-31].value"])

# Array parameters
selecto |> Selecto.join("multi_flags", flag_ids: [101, 102, 103])
selecto |> Selecto.select(["multi_flags[flag_ids: [101,102,103]].aggregated_value"])
```

### Conditional Join Parameters
```elixir
# Conditional joins based on other field values
selecto 
|> Selecto.join("flags", fn film -> 
     case film.category do
       "Action" -> [flag_id: 101]
       "Comedy" -> [flag_id: 102]
       _ -> [flag_id: 999]
     end
   end)
```

### Join Result Caching
```elixir
# Cache expensive join results
selecto 
|> Selecto.join("expensive_calculation", [param: 101], cache: true, ttl: :timer.minutes(5))
```

## Conclusion

This plan provides a comprehensive approach to enhancing Selecto with parameterized joins and modern dot notation syntax. The implementation maintains full backward compatibility while providing powerful new capabilities for dynamic join scenarios like the `film_flag` use case. The phased approach ensures stability during migration while delivering immediate value to developers.