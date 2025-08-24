# Selecto Multi-Database Integration Plan

## Overview

This plan outlines a highly extensible architecture for integrating Selecto with multiple database systems, starting with MySQL and Microsoft SQL Server. The architecture is designed to make adding new database adapters simple and consistent, requiring minimal code changes to the core system.

## Design Philosophy

The core principle is **database adapter modularity** - each database adapter is completely self-contained and pluggable. Adding a new database should require only:

1. Implementing a single adapter module
2. Adding the adapter to a registry  
3. Including database-specific dependencies

The core Selecto engine remains database-agnostic, with all database-specific logic encapsulated in adapters.

## Current Architecture Analysis

### Existing PostgreSQL Integration

Selecto currently integrates with PostgreSQL through:

1. **Connection Management**: `postgrex_opts` field in Selecto struct for Postgrex connections
2. **Execution Layer**: `Selecto.Executor` module handles query execution via Postgrex
3. **SQL Generation**: PostgreSQL-specific SQL dialects (ROLLUP, CTEs, window functions)
4. **Ecto Integration**: `Selecto.EctoAdapter` for Ecto repo connections

### Key Components Requiring Adaptation

- Connection management (currently Postgrex-only)
- SQL dialect differences (ROLLUP, date functions, limits)
- Parameter binding styles (PostgreSQL: $1, MySQL: ?, MSSQL: @param1)
- Data type mappings and conversions
- Advanced features (CTEs, window functions, lateral joins)

## 1. Extensible Database Adapter Architecture

### Plugin-Based Adapter System

The adapter system is designed for maximum extensibility. Each database adapter is a complete, self-contained module that can be loaded dynamically.

### Core Adapter Behavior

```elixir
defmodule Selecto.Adapters.Behavior do
  @moduledoc """
  Behavior that all database adapters must implement.
  This provides a complete contract for database integration.
  """
  
  # Connection Management
  @callback start_connection(opts :: keyword()) :: {:ok, connection :: any()} | {:error, any()}
  @callback stop_connection(connection :: any()) :: :ok
  @callback connection_alive?(connection :: any()) :: boolean()
  
  # Query Execution  
  @callback execute_query(connection :: any(), query :: String.t(), params :: [any()]) :: 
    {:ok, %{rows: [[any()]], columns: [String.t()]}} | {:error, any()}
    
  # SQL Transformation
  @callback transform_sql(query :: String.t()) :: String.t()
  @callback parameter_placeholders(count :: integer()) :: [String.t()]
  @callback parameter_style() :: :numbered | :question_mark | :named
  
  # Feature Support
  @callback features() :: %{atom() => boolean() | {:version, String.t()} | {:custom, any()}}
  @callback supports_feature?(feature :: atom()) :: boolean()
  
  # Type System
  @callback native_types() :: %{atom() => String.t()}
  @callback cast_value(value :: any(), type :: atom()) :: any()
  
  # Introspection
  @callback inspect_schema(connection :: any(), table :: String.t()) :: 
    {:ok, %{columns: [map()], indexes: [map()]}} | {:error, any()}
    
  # Adapter Metadata
  @callback adapter_name() :: String.t()
  @callback driver_module() :: module()
  @callback default_port() :: integer()
  
  # Connection Configuration
  @callback normalize_config(config :: keyword() | atom()) :: keyword()
  @callback validate_config(config :: keyword()) :: :ok | {:error, String.t()}
end
```

### Adapter Registry System

```elixir
defmodule Selecto.Adapters.Registry do
  @moduledoc """
  Dynamic registry for database adapters. 
  Makes adding new databases as simple as adding a module.
  """
  
  use GenServer
  
  @registry_table :selecto_adapters
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def register_adapter(identifier, adapter_module) do
    GenServer.call(__MODULE__, {:register, identifier, adapter_module})
  end
  
  def get_adapter(identifier) do
    case :ets.lookup(@registry_table, identifier) do
      [{^identifier, adapter_module}] -> {:ok, adapter_module}
      [] -> {:error, :adapter_not_found}
    end
  end
  
  def list_adapters() do
    :ets.tab2list(@registry_table)
  end
  
  def auto_discover_adapters() do
    # Automatically discover and register available adapters
    adapters = [
      {:postgresql, Selecto.Adapters.PostgreSQL},
      {:mysql, Selecto.Adapters.MySQL},
      {:mssql, Selecto.Adapters.MSSQL},
      {:sqlite, Selecto.Adapters.SQLite},
      {:clickhouse, Selecto.Adapters.ClickHouse},
      {:bigquery, Selecto.Adapters.BigQuery}
    ]
    
    Enum.each(adapters, fn {id, module} ->
      if Code.ensure_loaded?(module) do
        register_adapter(id, module)
      end
    end)
  end
  
  # GenServer callbacks
  def init(_opts) do
    :ets.new(@registry_table, [:set, :public, :named_table])
    auto_discover_adapters()
    {:ok, %{}}
  end
  
  def handle_call({:register, identifier, adapter_module}, _from, state) do
    # Validate adapter implements the behavior
    case validate_adapter(adapter_module) do
      :ok ->
        :ets.insert(@registry_table, {identifier, adapter_module})
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  defp validate_adapter(module) do
    behaviors = module.module_info(:attributes)[:behaviour] || []
    
    if Selecto.Adapters.Behavior in behaviors do
      :ok
    else
      {:error, "Module does not implement Selecto.Adapters.Behavior"}
    end
  end
end
```

### Sample Database Adapters

The following examples show how simple it is to add new database support. Each adapter is completely self-contained.

**PostgreSQL Adapter (existing, retrofitted to new interface)**
```elixir
defmodule Selecto.Adapters.PostgreSQL do
  @behaviour Selecto.Adapters.Behavior
  
  # Connection Management
  def start_connection(opts) do
    Postgrex.start_link(opts)
  end
  
  def stop_connection(conn), do: GenServer.stop(conn)
  def connection_alive?(conn), do: Process.alive?(conn)
  
  # Query Execution
  def execute_query(conn, query, params) do
    case Postgrex.query(conn, query, params) do
      {:ok, result} -> {:ok, %{rows: result.rows, columns: result.columns}}
      {:error, reason} -> {:error, reason}
    end
  end
  
  # SQL Transformation (PostgreSQL is the reference, no transformation needed)
  def transform_sql(query), do: query
  def parameter_placeholders(count), do: Enum.map(1..count, &"$#{&1}")
  def parameter_style(), do: :numbered
  
  # Feature Support
  def features() do
    %{
      rollup: true,
      cube: true,
      grouping: true,
      ctes: true,
      recursive_ctes: true,
      window_functions: true,
      lateral_joins: true,
      full_text_search: true,
      arrays: true,
      json: true,
      upsert: {:on_conflict, "ON CONFLICT"}
    }
  end
  
  def supports_feature?(feature), do: Map.get(features(), feature, false)
  
  # Type System
  def native_types() do
    %{
      integer: "INTEGER",
      bigint: "BIGINT", 
      string: "TEXT",
      boolean: "BOOLEAN",
      datetime: "TIMESTAMP",
      date: "DATE",
      decimal: "DECIMAL",
      float: "REAL",
      uuid: "UUID",
      json: "JSONB",
      array: "ARRAY"
    }
  end
  
  def cast_value(value, _type), do: value  # PostgreSQL handles most casting
  
  # Introspection
  def inspect_schema(conn, table) do
    query = """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns 
    WHERE table_name = $1
    ORDER BY ordinal_position
    """
    
    case execute_query(conn, query, [table]) do
      {:ok, %{rows: rows}} -> 
        columns = Enum.map(rows, fn [name, type, nullable] ->
          %{name: name, type: type, nullable: nullable == "YES"}
        end)
        {:ok, %{columns: columns, indexes: []}}
      error -> error
    end
  end
  
  # Adapter Metadata
  def adapter_name(), do: "PostgreSQL"
  def driver_module(), do: Postgrex
  def default_port(), do: 5432
  
  # Configuration
  def normalize_config(repo) when is_atom(repo), do: repo.config()
  def normalize_config(config) when is_list(config), do: config
  
  def validate_config(config) do
    required = [:username, :database]
    missing = required -- Keyword.keys(config)
    
    if missing == [] do
      :ok
    else
      {:error, "Missing required config: #{inspect(missing)}"}
    end
  end
end
```

**MySQL Adapter (new)**
```elixir
defmodule Selecto.Adapters.MySQL do
  @behaviour Selecto.Adapters.Behavior
  
  # Connection Management
  def start_connection(opts) do
    MyXQL.start_link(opts)
  end
  
  def stop_connection(conn), do: GenServer.stop(conn)
  def connection_alive?(conn), do: Process.alive?(conn)
  
  # Query Execution
  def execute_query(conn, query, params) do
    case MyXQL.query(conn, query, params) do
      {:ok, result} -> {:ok, %{rows: result.rows, columns: result.columns}}
      {:error, reason} -> {:error, reason}
    end
  end
  
  # SQL Transformation
  def transform_sql(query) do
    query
    |> String.replace("NOW()", "NOW()")
    |> String.replace("CURRENT_TIMESTAMP", "NOW()")
    |> transform_limit_syntax()
    |> transform_rollup_syntax()
  end
  
  def parameter_placeholders(count), do: List.duplicate("?", count)
  def parameter_style(), do: :question_mark
  
  # Feature Support  
  def features() do
    %{
      rollup: true,
      cube: false,
      grouping: true,
      ctes: {:version, "8.0"},
      recursive_ctes: {:version, "8.0"},
      window_functions: {:version, "8.0"},
      lateral_joins: false,
      full_text_search: true,
      arrays: false,
      json: {:version, "5.7"},
      upsert: {:on_duplicate, "ON DUPLICATE KEY UPDATE"}
    }
  end
  
  def supports_feature?(feature) do
    case Map.get(features(), feature, false) do
      true -> true
      false -> false
      {:version, _} -> true  # Assume modern MySQL
      {_, _} -> true
    end
  end
  
  # Type System
  def native_types() do
    %{
      integer: "INT",
      bigint: "BIGINT",
      string: "VARCHAR(255)",
      boolean: "BOOLEAN", 
      datetime: "DATETIME",
      date: "DATE",
      decimal: "DECIMAL",
      float: "FLOAT",
      uuid: "CHAR(36)",
      json: "JSON",
      array: "JSON"  # MySQL doesn't have native arrays
    }
  end
  
  def cast_value(value, :boolean) when is_boolean(value) do
    if value, do: 1, else: 0
  end
  def cast_value(value, _type), do: value
  
  # Introspection
  def inspect_schema(conn, table) do
    query = """
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = ?
    ORDER BY ORDINAL_POSITION
    """
    
    case execute_query(conn, query, [table]) do
      {:ok, %{rows: rows}} ->
        columns = Enum.map(rows, fn [name, type, nullable] ->
          %{name: name, type: type, nullable: nullable == "YES"}
        end)
        {:ok, %{columns: columns, indexes: []}}
      error -> error
    end
  end
  
  # Adapter Metadata
  def adapter_name(), do: "MySQL"
  def driver_module(), do: MyXQL
  def default_port(), do: 3306
  
  # Configuration
  def normalize_config(repo) when is_atom(repo), do: repo.config()
  def normalize_config(config) when is_list(config), do: config
  
  def validate_config(config) do
    required = [:username, :database]
    missing = required -- Keyword.keys(config)
    
    if missing == [] do
      :ok
    else
      {:error, "Missing required config: #{inspect(missing)}"}
    end
  end
  
  # Private helpers
  defp transform_limit_syntax(query) do
    # Transform PostgreSQL LIMIT x OFFSET y to MySQL LIMIT y, x
    Regex.replace(~r/LIMIT (\d+) OFFSET (\d+)/i, query, "LIMIT \\2, \\1")
  end
  
  defp transform_rollup_syntax(query) do
    # MySQL uses same ROLLUP syntax as PostgreSQL
    query
  end
end
```

**New Database Example: ClickHouse Adapter**
```elixir
defmodule Selecto.Adapters.ClickHouse do
  @behaviour Selecto.Adapters.Behavior
  
  # This shows how easy it is to add a new database!
  # Just implement the behavior and register it.
  
  def start_connection(opts) do
    # ClickHouse uses HTTP interface
    {:ok, %{base_url: build_url(opts), auth: build_auth(opts)}}
  end
  
  def execute_query(conn, query, params) do
    # HTTP-based query execution
    url = "#{conn.base_url}/?query=" <> URI.encode(query)
    
    case HTTPoison.get(url, [{"Authorization", conn.auth}]) do
      {:ok, %{body: body}} -> 
        {rows, columns} = parse_clickhouse_response(body)
        {:ok, %{rows: rows, columns: columns}}
      {:error, reason} -> {:error, reason}
    end
  end
  
  def transform_sql(query) do
    query
    |> String.replace("ROLLUP", "WITH ROLLUP")
    |> transform_clickhouse_types()
  end
  
  def features() do
    %{
      rollup: true,
      cube: true,
      window_functions: true,
      arrays: true,
      materialized_views: true,
      distributed_queries: true
    }
  end
  
  # ... implement remaining callbacks ...
  
  def adapter_name(), do: "ClickHouse"
  def driver_module(), do: HTTPoison
  def default_port(), do: 8123
end
```

### Adding New Database Adapters

Adding support for a new database is incredibly simple:

1. **Create the adapter module** implementing `Selecto.Adapters.Behavior`
2. **Register it with the registry** (happens automatically on app start)
3. **Add the database driver dependency** to mix.exs
4. **Use it immediately**

```elixir
# The registry automatically discovers and loads available adapters
# New databases work immediately with existing Selecto code

# PostgreSQL
selecto = Selecto.configure(domain, :postgresql, postgres_config)

# MySQL  
selecto = Selecto.configure(domain, :mysql, mysql_config)

# MSSQL
selecto = Selecto.configure(domain, :mssql, mssql_config)

# ClickHouse (if adapter is available)
selecto = Selecto.configure(domain, :clickhouse, clickhouse_config)

# Same API, different databases!
result = selecto |> Selecto.select([:name]) |> Selecto.execute()
```

## 2. SQL Dialect Abstraction Layer

### Dialect Manager

```elixir
defmodule Selecto.SQL.DialectManager do
  @moduledoc """
  Manages SQL dialect transformations and feature compatibility.
  """
  
  def transform_query(query, from_dialect, to_dialect) do
    case to_dialect do
      :postgresql -> query  # No transformation needed
      :mysql -> transform_to_mysql(query)
      :mssql -> transform_to_mssql(query)
    end
  end
  
  defp transform_to_mysql(query) do
    query
    |> replace_function("NOW()", "NOW()")
    |> replace_function("CURRENT_TIMESTAMP", "NOW()")
    |> transform_limit_offset_mysql()
    |> handle_rollup_mysql()
  end
  
  defp transform_to_mssql(query) do
    query
    |> replace_function("NOW()", "GETDATE()")
    |> replace_function("CURRENT_TIMESTAMP", "GETDATE()")
    |> transform_limit_to_top()
    |> handle_rollup_mssql()
    |> escape_identifiers_mssql()
  end
end
```

### Feature Compatibility Matrix

```elixir
defmodule Selecto.SQL.Features do
  @features %{
    postgresql: %{
      rollup: true,
      cube: true,
      grouping: true,
      ctes: true,
      recursive_ctes: true,
      window_functions: true,
      lateral_joins: true,
      full_text_search: true,
      arrays: true,
      json: true,
      upsert: {:on_conflict, "ON CONFLICT"}
    },
    mysql: %{
      rollup: true,
      cube: false,
      grouping: true,
      ctes: {:version, "8.0"},
      recursive_ctes: {:version, "8.0"},
      window_functions: {:version, "8.0"},
      lateral_joins: false,
      full_text_search: true,
      arrays: false,
      json: {:version, "5.7"},
      upsert: {:on_duplicate, "ON DUPLICATE KEY UPDATE"}
    },
    mssql: %{
      rollup: true,
      cube: true,
      grouping: true,
      ctes: true,
      recursive_ctes: true,
      window_functions: true,
      lateral_joins: {:apply, "CROSS APPLY / OUTER APPLY"},
      full_text_search: true,
      arrays: false,
      json: {:version, "2016"},
      upsert: {:merge, "MERGE"}
    }
  }
end
```

## 3. Connection Management Strategy

### Unified Connection Interface

```elixir
defmodule Selecto.Connection do
  @moduledoc """
  Unified connection management for different database adapters.
  """
  
  defstruct [:adapter, :connection, :config, :dialect]
  
  def new(adapter_type, connection_opts) do
    adapter = get_adapter(adapter_type)
    dialect = get_dialect(adapter_type)
    
    %__MODULE__{
      adapter: adapter,
      connection: connection_opts,
      config: adapter.connection_config(connection_opts),
      dialect: dialect
    }
  end
  
  defp get_adapter(:postgresql), do: Selecto.Adapters.PostgreSQL
  defp get_adapter(:mysql), do: Selecto.Adapters.MySQL  
  defp get_adapter(:mssql), do: Selecto.Adapters.MSSQL
end
```

### Modified Selecto Struct

```elixir
defmodule Selecto do
  # Replace postgrex_opts with generic connection
  defstruct [:connection, :domain, :config, :set]
  
  def configure(domain, connection_or_repo, opts \\ []) do
    connection = normalize_connection(connection_or_repo)
    
    %Selecto{
      connection: connection,
      domain: domain,
      config: build_config(domain, opts),
      set: %{}
    }
  end
  
  defp normalize_connection(repo) when is_atom(repo) do
    # Detect database type from Ecto repo configuration
    adapter = get_ecto_adapter(repo)
    dialect = adapter_to_dialect(adapter)
    
    Selecto.Connection.new(dialect, repo)
  end
  
  defp normalize_connection({dialect, connection_opts}) do
    Selecto.Connection.new(dialect, connection_opts)
  end
end
```

### Database Detection

```elixir
defmodule Selecto.DatabaseDetector do
  def detect_from_ecto_repo(repo) do
    config = repo.config()
    
    case config[:adapter] do
      Ecto.Adapters.Postgres -> :postgresql
      Ecto.Adapters.MyXQL -> :mysql
      Ecto.Adapters.Tds -> :mssql
      _ -> raise "Unsupported database adapter"
    end
  end
  
  def detect_from_connection(connection) do
    cond do
      is_pid(connection) && Process.info(connection, :dictionary)[:postgrex] -> :postgresql
      is_pid(connection) && Process.info(connection, :dictionary)[:myxql] -> :mysql
      is_pid(connection) && Process.info(connection, :dictionary)[:tds] -> :mssql
      true -> :unknown
    end
  end
end
```

## 4. Enhanced Executor Module

### Multi-Database Executor

```elixir
defmodule Selecto.Executor do
  def execute(selecto, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      {query, aliases, params} = Selecto.gen_sql(selecto, opts)
      
      # Transform SQL for target database
      transformed_query = transform_sql_for_dialect(query, selecto.connection.dialect)
      
      # Transform parameters for target database
      transformed_params = transform_params(params, selecto.connection.adapter.parameter_style())
      
      # Execute with appropriate adapter
      result = selecto.connection.adapter.execute_query(
        selecto.connection.connection, 
        transformed_query, 
        transformed_params
      )
      
      case result do
        {:ok, %{rows: rows, columns: columns}} -> 
          {:ok, {rows, columns, aliases}}
        {:error, reason} -> 
          {:error, Selecto.Error.from_reason(reason)}
      end
      
    rescue
      error -> {:error, Selecto.Error.from_reason(error)}
    end
  end
  
  defp transform_sql_for_dialect(query, dialect) do
    if dialect == :postgresql do
      query
    else
      Selecto.SQL.DialectManager.transform_query(query, :postgresql, dialect)
    end
  end
  
  defp transform_params(params, :numbered) do
    # PostgreSQL style: $1, $2, $3 (no transformation needed)
    params
  end
  
  defp transform_params(params, :question_mark) do
    # MySQL style: ?, ?, ? (no transformation needed for params, only query)
    params
  end
  
  defp transform_params(params, :named) do
    # MSSQL style: @param1, @param2, @param3 (params stay the same, query gets transformed)
    params
  end
end
```

## 5. SQL Generation Modifications

### Feature-Aware SQL Builder

```elixir
defmodule Selecto.Builder.SQL do
  def build_rollup_clause(group_by_fields, %{dialect: dialect} = _context) do
    if Selecto.SQL.Features.supports?(dialect, :rollup) do
      case dialect do
        :postgresql -> build_postgresql_rollup(group_by_fields)
        :mysql -> build_mysql_rollup(group_by_fields)
        :mssql -> build_mssql_rollup(group_by_fields)
      end
    else
      # Fallback: simulate ROLLUP with UNION ALL
      build_rollup_simulation(group_by_fields, dialect)
    end
  end
  
  def build_limit_clause(limit, offset, dialect) do
    case dialect do
      :postgresql -> "LIMIT #{limit} OFFSET #{offset}"
      :mysql -> "LIMIT #{offset}, #{limit}"
      :mssql when offset == 0 -> "TOP #{limit}"
      :mssql -> "OFFSET #{offset} ROWS FETCH NEXT #{limit} ROWS ONLY"
    end
  end
  
  def build_date_function(function, dialect) do
    case {function, dialect} do
      {:now, :postgresql} -> "NOW()"
      {:now, :mysql} -> "NOW()"
      {:now, :mssql} -> "GETDATE()"
      
      {:current_timestamp, :postgresql} -> "CURRENT_TIMESTAMP"
      {:current_timestamp, :mysql} -> "NOW()"
      {:current_timestamp, :mssql} -> "GETDATE()"
      
      {:date_trunc, :postgresql} -> "DATE_TRUNC"
      {:date_trunc, :mysql} -> "DATE_FORMAT"
      {:date_trunc, :mssql} -> "FORMAT"
    end
  end
end
```

## 6. Data Type Mapping

### Cross-Database Type System

```elixir
defmodule Selecto.Types.CrossDatabase do
  @type_mappings %{
    # Selecto Type => {PostgreSQL, MySQL, MSSQL}
    :integer => {"INTEGER", "INT", "INT"},
    :bigint => {"BIGINT", "BIGINT", "BIGINT"},
    :string => {"TEXT", "VARCHAR", "NVARCHAR"},
    :boolean => {"BOOLEAN", "BOOLEAN", "BIT"},
    :datetime => {"TIMESTAMP", "DATETIME", "DATETIME2"},
    :date => {"DATE", "DATE", "DATE"},
    :decimal => {"DECIMAL", "DECIMAL", "DECIMAL"},
    :float => {"REAL", "FLOAT", "FLOAT"},
    :uuid => {"UUID", "CHAR(36)", "UNIQUEIDENTIFIER"},
    :json => {"JSONB", "JSON", "NVARCHAR(MAX)"},
    :array => {"ARRAY", "JSON", "NVARCHAR(MAX)"}
  }
  
  def get_native_type(selecto_type, dialect) do
    case Map.get(@type_mappings, selecto_type) do
      {pg_type, mysql_type, mssql_type} ->
        case dialect do
          :postgresql -> pg_type
          :mysql -> mysql_type
          :mssql -> mssql_type
        end
      nil -> "TEXT"  # Fallback
    end
  end
end
```

## 7. Configuration and Setup

### Database-Specific Configuration

```elixir
# PostgreSQL (existing)
selecto = Selecto.configure(domain, SelectoTest.Repo)

# MySQL
selecto = Selecto.configure(domain, {:mysql, MyApp.MySQLRepo})

# MSSQL  
selecto = Selecto.configure(domain, {:mssql, MyApp.MSSQLRepo})

# Direct connections
mysql_opts = [
  hostname: "localhost",
  username: "root",
  password: "password",
  database: "myapp_dev"
]
selecto = Selecto.configure(domain, {:mysql, mysql_opts})

mssql_opts = [
  hostname: "localhost",
  username: "sa", 
  password: "Password123!",
  database: "MyAppDev",
  instance: "SQLEXPRESS"
]
selecto = Selecto.configure(domain, {:mssql, mssql_opts})
```

## 8. Testing and Validation Strategy

### Multi-Database Test Suite

```elixir
defmodule Selecto.MultiDatabaseTest do
  use ExUnit.Case
  
  @databases [:postgresql, :mysql, :mssql]
  
  setup do
    # Setup test databases for each dialect
    connections = setup_test_databases(@databases)
    %{connections: connections}
  end
  
  for database <- @databases do
    test "basic query execution works on #{database}", %{connections: connections} do
      selecto = configure_for_database(unquote(database), connections)
      
      result = selecto
               |> Selecto.select([:id, :name])
               |> Selecto.from(:users)
               |> Selecto.execute()
      
      assert {:ok, _} = result
    end
    
    test "ROLLUP functionality on #{database}", %{connections: connections} do
      selecto = configure_for_database(unquote(database), connections)
      
      if Selecto.SQL.Features.supports?(unquote(database), :rollup) do
        result = selecto
                 |> Selecto.select([:category, {:count, :id}])
                 |> Selecto.from(:products)
                 |> Selecto.group_by([:category], rollup: true)
                 |> Selecto.execute()
        
        assert {:ok, _} = result
      else
        # Test rollup simulation
        result = selecto
                 |> Selecto.select([:category, {:count, :id}])
                 |> Selecto.from(:products)
                 |> Selecto.group_by([:category], rollup: true)
                 |> Selecto.execute()
        
        assert {:ok, _} = result
      end
    end
  end
end
```

### Performance Benchmarking

```elixir
defmodule Selecto.PerformanceBenchmark do
  def run_benchmarks do
    databases = [:postgresql, :mysql, :mssql]
    
    for database <- databases do
      IO.puts("Benchmarking #{database}...")
      
      Benchee.run(%{
        "simple_select" => fn -> run_simple_select(database) end,
        "complex_join" => fn -> run_complex_join(database) end,
        "aggregation" => fn -> run_aggregation(database) end,
        "rollup" => fn -> run_rollup(database) end
      }, time: 10, memory_time: 2)
    end
  end
end
```

## 9. Migration and Compatibility

### Backward Compatibility

The existing PostgreSQL-focused API will remain unchanged:

```elixir
# Existing code continues to work
selecto = Selecto.configure(domain, postgrex_connection)
result = Selecto.execute(selecto)
```

### Migration Guide

```elixir
# Before (PostgreSQL only)
selecto = Selecto.configure(domain, SelectoTest.Repo)

# After (Multi-database)
# PostgreSQL (no change needed)
selecto = Selecto.configure(domain, SelectoTest.Repo)

# MySQL
selecto = Selecto.configure(domain, {:mysql, MyApp.MySQLRepo})

# MSSQL
selecto = Selecto.configure(domain, {:mssql, MyApp.MSSQLRepo})
```

## 10. Implementation Phases

### Phase 1: Core Infrastructure (4-6 weeks)
1. Design and implement adapter interface
2. Create MySQL and MSSQL adapters
3. Build SQL dialect abstraction layer
4. Modify core Selecto struct and configuration

### Phase 2: SQL Feature Mapping (3-4 weeks)
1. Implement basic SQL transformations
2. Handle parameter binding differences
3. Create feature compatibility matrix
4. Test basic query execution across databases

### Phase 3: Advanced Features (4-6 weeks)
1. Implement ROLLUP transformations for each database
2. Handle CTE translations
3. Implement window function compatibility
4. Add join type transformations

### Phase 4: Integration and Testing (3-4 weeks)
1. Comprehensive test suite across all databases
2. Performance benchmarking
3. Documentation and examples
4. Migration guide and compatibility testing

### Phase 5: SelectoComponents Integration (2-3 weeks)
1. Update SelectoComponents to work with multiple databases
2. Test LiveView components with different databases
3. Handle database-specific UI considerations
4. Performance optimization for different databases

## 11. Dependencies and Requirements

### New Dependencies

```elixir
# mix.exs additions
defp deps do
  [
    # Existing
    {:postgrex, "~> 0.19", optional: true},
    
    # New database adapters
    {:myxql, "~> 0.6", optional: true},
    {:tds, "~> 2.3", optional: true},
    
    # Testing and benchmarking
    {:benchee, "~> 1.0", only: :dev},
  ]
end
```

### System Requirements

- **MySQL**: 5.7+ (8.0+ recommended for full feature support)
- **SQL Server**: 2016+ (for JSON support and modern features)
- **PostgreSQL**: 12+ (existing requirement)

## 12. Maximum Extensibility Architecture

### Plugin System Design

The architecture prioritizes extensibility through several key design patterns:

#### 1. Zero-Core-Changes Policy

Adding a new database should never require changes to core Selecto code. The system is designed to be completely open for extension but closed for modification.

```elixir
# Core Selecto never needs to know about specific databases
defmodule Selecto.Core do
  def execute(selecto) do
    adapter = Selecto.Adapters.Registry.get_adapter!(selecto.adapter_type)
    
    # Transform SQL using adapter
    query = adapter.transform_sql(selecto.query)
    params = adapter.transform_params(selecto.params)
    
    # Execute using adapter
    adapter.execute_query(selecto.connection, query, params)
  end
end
```

#### 2. Adapter Development Kit

To make adding new adapters as easy as possible, provide development tools:

```elixir
defmodule Selecto.AdapterKit do
  @moduledoc """
  Utilities to make building new database adapters trivial.
  """
  
  defmacro __using__(opts) do
    quote do
      @behaviour Selecto.Adapters.Behavior
      
      # Provide sensible defaults for common adapter patterns
      use Selecto.AdapterKit.Defaults
      use Selecto.AdapterKit.SQLHelpers
      use Selecto.AdapterKit.TestSuite
      
      # Allow selective overrides
      defoverridable unquote(opts[:overridable] || [])
    end
  end
  
  def generate_adapter(database_name, driver_module) do
    # Generate a complete adapter skeleton
    # This could be a Mix task: mix selecto.gen.adapter clickhouse HTTPoison
    template = """
    defmodule Selecto.Adapters.#{Macro.camelize(database_name)} do
      use Selecto.AdapterKit, overridable: [:transform_sql, :features]
      
      def driver_module(), do: #{driver_module}
      def adapter_name(), do: "#{String.capitalize(database_name)}"
      
      # Override specific methods as needed
      def transform_sql(query) do
        # Add #{database_name}-specific transformations
        query
      end
      
      def features() do
        # Define #{database_name} capabilities
        %{}
      end
    end
    """
    
    File.write!("lib/selecto/adapters/#{database_name}.ex", template)
  end
end
```

#### 3. Adapter Testing Framework

Every adapter gets the same comprehensive test suite for free:

```elixir
defmodule Selecto.AdapterKit.TestSuite do
  defmacro __using__(_opts) do
    quote do
      def run_adapter_tests(connection_config) do
        # Automatically generated test suite that validates:
        # - Connection management
        # - Query execution  
        # - SQL transformation
        # - Feature support
        # - Error handling
        # - Performance benchmarks
        
        Selecto.AdapterKit.TestRunner.run_all_tests(__MODULE__, connection_config)
      end
    end
  end
end
```

#### 4. Feature Detection and Fallbacks

The system automatically handles feature differences:

```elixir
defmodule Selecto.Features.AutoFallback do
  def execute_with_fallback(adapter, feature, primary_fn, fallback_fn) do
    if adapter.supports_feature?(feature) do
      primary_fn.()
    else
      fallback_fn.()
    end
  end
end

# Usage in Selecto core
def build_rollup(selecto) do
  Selecto.Features.AutoFallback.execute_with_fallback(
    selecto.adapter,
    :rollup,
    fn -> build_native_rollup(selecto) end,
    fn -> build_union_rollup_simulation(selecto) end
  )
end
```

#### 5. Adapter Composition

Allow adapters to extend other adapters for related databases:

```elixir
defmodule Selecto.Adapters.MariaDB do
  use Selecto.Adapters.MySQL, extend: true
  
  # MariaDB is mostly MySQL-compatible, just override differences
  def adapter_name(), do: "MariaDB"
  def default_port(), do: 3306
  
  def features() do
    # Inherit MySQL features but add MariaDB-specific ones
    super()
    |> Map.put(:sequences, true)
    |> Map.put(:temporal_tables, true)
  end
end
```

#### 6. Runtime Adapter Discovery

The system discovers available adapters automatically:

```elixir
defmodule Selecto.Discovery do
  def discover_adapters() do
    # Scan for modules implementing the behavior
    :code.all_loaded()
    |> Enum.filter(fn {module, _} ->
      case module.module_info(:attributes)[:behaviour] || [] do
        behaviours when is_list(behaviours) ->
          Selecto.Adapters.Behavior in behaviours
        _ -> false
      end
    end)
    |> Enum.map(&elem(&1, 0))
  end
  
  def available_databases() do
    discover_adapters()
    |> Enum.map(fn adapter ->
      {
        adapter.adapter_name() |> String.downcase() |> String.to_atom(),
        adapter
      }
    end)
    |> Map.new()
  end
end

# Usage
iex> Selecto.Discovery.available_databases()
%{
  postgresql: Selecto.Adapters.PostgreSQL,
  mysql: Selecto.Adapters.MySQL,
  mariadb: Selecto.Adapters.MariaDB,
  mssql: Selecto.Adapters.MSSQL,
  clickhouse: Selecto.Adapters.ClickHouse,
  sqlite: Selecto.Adapters.SQLite
}
```

#### 7. Configuration-Driven Adapters

For databases with minimal differences, allow configuration-only adapters:

```elixir
# config/config.exs
config :selecto, :custom_adapters,
  snowflake: [
    base_adapter: Selecto.Adapters.PostgreSQL,
    transform_sql: [
      {"LIMIT", "TOP"},
      {"OFFSET", "SKIP"}
    ],
    features: [
      rollup: true,
      window_functions: true,
      json: true
    ],
    driver: :odbc,
    default_port: 443
  ]

# Automatically generates Selecto.Adapters.Snowflake
```

#### 8. Adapter Package System

Make adapters distributable as separate packages:

```elixir
# In a separate hex package: selecto_clickhouse
defmodule SelectoClickhouse.Adapter do
  use Selecto.AdapterKit
  
  def adapter_name(), do: "ClickHouse"
  # ... implementation
end

# In mix.exs
{:selecto_clickhouse, "~> 1.0"}

# Automatic registration on app start
defmodule SelectoClickhouse.Application do
  def start(_type, _args) do
    Selecto.Adapters.Registry.register_adapter(:clickhouse, SelectoClickhouse.Adapter)
    {:ok, self()}
  end
end
```

### Future Database Candidates

The extensible architecture makes it trivial to add support for:

- **SQLite** - Embedded database support
- **ClickHouse** - OLAP and analytics workloads
- **BigQuery** - Google Cloud data warehouse
- **Snowflake** - Cloud data platform
- **Redshift** - Amazon data warehouse  
- **CockroachDB** - Distributed SQL
- **TimescaleDB** - Time-series PostgreSQL extension
- **DuckDB** - In-process analytical database
- **Apache Drill** - Schema-free SQL engine
- **Presto/Trino** - Distributed SQL engine

Each would require only implementing the adapter interface - no core Selecto changes needed.

## 13. Documentation and Examples

### Usage Examples

```elixir
# Cross-database domain definition
domain = %{
  source: %{
    source_table: "users",
    fields: [:id, :name, :email, :created_at],
    columns: %{
      id: %{type: :integer},
      name: %{type: :string},
      email: %{type: :string},  
      created_at: %{type: :datetime}
    }
  }
}

# PostgreSQL
pg_selecto = Selecto.configure(domain, MyApp.PostgresRepo)

# MySQL  
mysql_selecto = Selecto.configure(domain, {:mysql, MyApp.MySQLRepo})

# SQL Server
mssql_selecto = Selecto.configure(domain, {:mssql, MyApp.MSSQLRepo})

# Same query API across all databases
result = selecto
          |> Selecto.select([:name, {:count, :id}])
          |> Selecto.from(:users)
          |> Selecto.group_by([:name])
          |> Selecto.execute()
```

This comprehensive plan provides a roadmap for extending Selecto to support MySQL and MSSQL while maintaining the existing PostgreSQL functionality and ensuring backward compatibility. The modular architecture allows for easy addition of new database adapters in the future.