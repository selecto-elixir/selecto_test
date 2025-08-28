# Output Format Enhancement Plan

## Current Status - August 28, 2025

### ✅ Completed Implementation (PHASE COMPLETE!)
- **Core Infrastructure**: Format registry, type coercion system, error handling
- **Maps Transformer**: Full implementation with key transformations, type coercion, streaming
- **Structs Transformer**: Dynamic struct creation, field mapping, validation, streaming support  
- **JSON Transformer**: Complete with configurable serialization, metadata, null handling, pretty printing
- **CSV Transformer**: Production-ready implementation with all standard CSV features
- **Test Coverage**: Comprehensive test suites (91/91 tests passing - 38 CSV, 25 JSON, 18 Structs, 9 Maps, 1 TypeCoercion)
- **Integration**: Complete integration with Selecto.Executor via format parameter

### 🎉 CSV Transformer - COMPLETED!
- **Headers**: Optional column headers with configurable inclusion
- **Custom Delimiters**: Support for comma, tab, semicolon, pipe, and custom separators  
- **Quote Handling**: Configurable quote characters with proper escaping
- **Special Characters**: Proper handling of embedded newlines, commas, quotes in fields
- **Null Values**: Configurable null value representation
- **Line Endings**: Support for LF, CRLF, and custom line endings
- **Force Quotes**: Option to quote all fields regardless of content
- **Streaming Support**: Efficient processing for large datasets with consistent behavior
- **RFC 4180 Compliance**: Follows CSV standards with configurable extensions
- **Type Integration**: Full PostgreSQL type system integration with coercion

### 📋 Future Enhancements (Optional)
- Advanced streaming transformer optimizations
- Integration testing and comprehensive documentation
- Additional export formats (Excel, Parquet, etc.)

### 📂 Implemented Files
```
vendor/selecto/lib/selecto/output/
├── formats.ex                     ✅ Core format registry and dispatcher
├── type_coercion.ex              ✅ PostgreSQL type mapping and coercion
├── transformers/
│   ├── maps.ex                   ✅ Map format with key transformations
│   ├── structs.ex                ✅ Struct format with field mapping
│   ├── json.ex                   ✅ JSON serialization with metadata
│   └── csv.ex                    ✅ CSV export with full feature set
└── (future)
    └── stream.ex                 � Optional: Advanced streaming optimizations

vendor/selecto/lib/selecto/
├── executor.ex                   ✅ Enhanced with format parameter support  
└── error.ex                      ✅ Extended with transformation error types

test/selecto/output/transformers/
├── json_test.exs                 ✅ JSON transformer tests (25/25 passing)
└── csv_test.exs                  ✅ CSV transformer tests (38/38 passing)

vendor/selecto/test/selecto/output/
├── formats_test.exs              ✅ Format registry tests
├── type_coercion_test.exs        ✅ Type coercion tests (1/1 passing)
└── transformers/
    ├── maps_test.exs             ✅ Maps transformer tests (9/9 passing)
    └── structs_test.exs          ✅ Structs transformer tests (18/18 passing)
```

---

## Overview

Enhance Selecto's result output formats beyond the current list-of-lists structure to support maps, structs, JSON, CSV, and streaming formats that better match different use cases and integration requirements.

## Current State Analysis

### Existing Output Format
```elixir
# Current Selecto.execute/2 returns:
{:ok, {rows, columns, aliases}} = Selecto.execute(selecto)

# Where:
rows = [
  ["John Doe", "john@example.com", 25],
  ["Jane Smith", "jane@example.com", 30]
]
columns = ["name", "email", "age"]
aliases = %{"name" => "customer_name", "email" => "customer_email", "age" => "customer_age"}
```

### Limitations
- Manual column/row correlation required
- No type information preserved
- Difficult integration with JSON APIs
- Not suitable for stream processing
- Limited compatibility with Ecto/Phoenix patterns

## Architecture Design

### Core Module Structure
```
vendor/selecto/lib/selecto/output/                # Output format namespace
├── formats.ex                                    # Format registry and configuration
├── transformers/                                 # Format-specific transformers
│   ├── maps.ex                                   # List of maps transformer
│   ├── structs.ex                                # Struct-based output
│   ├── json.ex                                   # JSON serialization
│   ├── csv.ex                                    # CSV export functionality
│   ├── stream.ex                                 # Streaming output
│   └── custom.ex                                 # User-defined transformers
├── type_coercion.ex                              # Database type to Elixir type conversion
└── formatters/                                   # Specialized formatters
    ├── phoenix.ex                                # Phoenix/LiveView integration
    ├── ecto.ex                                   # Ecto struct compatibility
    └── api.ex                                    # REST API response formatting
```

### API Design

#### Output Format Configuration
```elixir
# Configure output format during query execution
{:ok, results} = selecto
  |> Selecto.execute(format: :maps)

# Results as list of maps:
results = [
  %{"name" => "John Doe", "email" => "john@example.com", "age" => 25},
  %{"name" => "Jane Smith", "email" => "jane@example.com", "age" => 30}
]

# Configure with options
{:ok, results} = selecto
  |> Selecto.execute(format: {:maps, keys: :atoms, types: :coerce})

# Results with atom keys and type coercion:
results = [
  %{name: "John Doe", email: "john@example.com", age: 25},
  %{name: "Jane Smith", email: "jane@example.com", age: 30}
]
```

#### Struct-Based Output
```elixir
# Define result struct
defmodule Customer do
  defstruct [:name, :email, :age, :created_at]
end

# Execute with struct format
{:ok, customers} = selecto
  |> Selecto.execute(format: {:structs, Customer})

# Results as structs:
customers = [
  %Customer{name: "John Doe", email: "john@example.com", age: 25, created_at: ~U[2023-01-01 10:00:00Z]},
  %Customer{name: "Jane Smith", email: "jane@example.com", age: 30, created_at: ~U[2023-02-01 15:30:00Z]}
]

# Auto-generate struct from domain
{:ok, customers} = selecto
  |> Selecto.execute(format: {:auto_struct, "Customer"})
# Generates struct based on selected fields and types
```

#### JSON Export
```elixir
# Direct JSON export
{:ok, json_string} = selecto
  |> Selecto.execute(format: :json)

json_string = """
[
  {"name": "John Doe", "email": "john@example.com", "age": 25},
  {"name": "Jane Smith", "email": "jane@example.com", "age": 30}
]
"""

# JSON with metadata
{:ok, response} = selecto
  |> Selecto.execute(format: {:json, include_meta: true})

response = """
{
  "data": [...],
  "meta": {
    "total_rows": 2,
    "columns": ["name", "email", "age"],
    "query_time_ms": 45,
    "generated_at": "2023-01-01T10:00:00Z"
  }
}
"""
```

#### CSV Export ✅ IMPLEMENTED
```elixir
# Basic CSV string export
{:ok, csv_string} = selecto
  |> Selecto.execute(format: :csv)

csv_string = """
name,email,age
John Doe,john@example.com,25
Jane Smith,jane@example.com,30
"""

# CSV with comprehensive options (all implemented)
{:ok, csv_string} = selecto
  |> Selecto.execute(format: {:csv, [
      headers: true,           # Include column headers
      delimiter: "|",          # Custom field separator  
      quote_char: "'",         # Custom quote character
      line_ending: "\r\n",     # Windows line endings
      null_value: "NULL",      # Custom null representation
      force_quotes: false      # Only quote when necessary
    ]})

# Streaming CSV for large datasets
stream = selecto
  |> Selecto.stream(format: :csv, batch_size: 10000)

# Results properly handle special characters:
# - Embedded commas: "Smith, John",25
# - Embedded quotes: "He said ""Hello""",30  
# - Embedded newlines: "Line 1\nLine 2",42
```

#### Streaming Output
```elixir
# Stream results for large datasets
stream = selecto
  |> Selecto.stream(format: :maps, batch_size: 1000)

# Process results in batches
stream
|> Stream.each(fn batch ->
     Enum.each(batch, &process_customer/1)
   end)
|> Stream.run()

# Stream to file
selecto
|> Selecto.stream(format: :json_lines, batch_size: 5000)
|> Stream.into(File.stream!("large_export.jsonl"))
|> Stream.run()
```

## Output Format Types

### 1. Maps (Key-Value Pairs)
```elixir
format_options = [
  :maps,                              # Default string keys
  {:maps, keys: :atoms},              # Atom keys for performance
  {:maps, keys: :strings},            # Explicit string keys
  {:maps, keys: :existing_atoms},     # Only existing atoms (safe)
  {:maps, transform: &custom_transform/1}  # Custom transformation
]

# Example output formats:
%{"customer_name" => "John", "total_orders" => 5}           # strings
%{customer_name: "John", total_orders: 5}                   # atoms  
%{"customerName" => "John", "totalOrders" => 5}             # camelCase transform
```

### 2. Structs
```elixir
struct_options = [
  {:structs, MyApp.Customer},                    # Predefined struct
  {:auto_struct, "Customer"},                    # Generate struct from query
  {:dynamic_struct, fields: [:name, :email]},   # Dynamic struct creation
  {:ecto_struct, MyApp.Repo, MyApp.User}        # Ecto schema compatibility
]
```

### 3. Typed Results  
```elixir
# Preserve PostgreSQL types in Elixir
typed_options = [
  {:typed_maps, coerce: :all},           # Coerce all types
  {:typed_maps, coerce: [:date, :json]}, # Coerce specific types
  {:typed_maps, preserve: [:decimal]},   # Preserve as strings
  {:typed_structs, MyStruct, coerce: :safe} # Safe type coercion
]

# Example with type coercion:
%{
  name: "John Doe",                    # VARCHAR -> String
  age: 25,                            # INTEGER -> Integer  
  salary: Decimal.new("50000.00"),    # NUMERIC -> Decimal
  created_at: ~U[2023-01-01 10:00:00Z], # TIMESTAMPTZ -> DateTime
  preferences: %{"theme" => "dark"}    # JSONB -> Map
}
```

### 4. Hierarchical Output
```elixir
# Nested data structures from JOINs
hierarchical_options = [
  :nested,                           # Automatic nesting based on joins
  {:nested, strategy: :group_by},    # Group related records
  {:nested, depth: 2},               # Limit nesting depth
  {:tree, parent_key: :parent_id}    # Tree structure for hierarchical data
]

# Example nested output:
[
  %{
    customer: %{
      id: 1,
      name: "John Doe",
      email: "john@example.com"
    },
    orders: [
      %{id: 101, total: 250.00, date: ~D[2023-01-15]},
      %{id: 102, total: 175.50, date: ~D[2023-02-01]}
    ],
    address: %{
      street: "123 Main St",
      city: "Boston", 
      state: "MA"
    }
  }
]
```

### 5. Paginated Output
```elixir
# Built-in pagination support
paginated_options = [
  {:paginated, page: 1, per_page: 20},
  {:paginated, cursor: "eyJ0aW1lc3RhbXA", limit: 50},
  {:paginated, strategy: :offset}  # or :cursor, :keyset
]

# Paginated result format:
%{
  data: [...],                     # Current page data
  pagination: %{
    current_page: 1,
    per_page: 20,
    total_pages: 15,
    total_count: 289,
    has_next: true,
    has_prev: false,
    next_cursor: "eyJ0aW1lc3RhbXA...",
    prev_cursor: nil
  },
  meta: %{
    query_time_ms: 42,
    generated_at: ~U[2023-01-01 10:00:00Z]
  }
}
```

## Implementation Phases

### Phase 1: Core Format Infrastructure (Week 1-2) ✅ COMPLETED
- [x] Output format registry and configuration system (`/vendor/selecto/lib/selecto/output/formats.ex`)
- [x] Basic type coercion framework (`/vendor/selecto/lib/selecto/output/type_coercion.ex`)
- [x] Maps format with string/atom key options (`/vendor/selecto/lib/selecto/output/transformers/maps.ex`)
- [x] Integration with existing execute/2 functions (`/vendor/selecto/lib/selecto/executor.ex`)
- [x] Enhanced error handling system (`/vendor/selecto/lib/selecto/error.ex`)
- [x] Comprehensive test infrastructure (9/9 Maps tests passing)

### Phase 1.2: Structs Format ✅ COMPLETED  
- [x] Struct-based output with dynamic creation (`/vendor/selecto/lib/selecto/output/transformers/structs.ex`)
- [x] Field mapping and validation with `@enforce_keys` support
- [x] Type coercion integration for struct fields
- [x] Streaming support for large datasets via `stream_transform/5`
- [x] Full test coverage (18/18 tests passing)

### Phase 1.3: JSON Format ✅ COMPLETED
- [x] JSON serialization with configurable options (`/vendor/selecto/lib/selecto/output/transformers/json.ex`)
- [x] Metadata inclusion and pretty printing support
- [x] Null handling and custom serialization options
- [x] Integration with Jason library for performance
- [x] Comprehensive test coverage (25/25 tests passing)

### Phase 1.4: CSV Format ✅ COMPLETED
- [x] CSV export functionality with headers and custom delimiters (`/vendor/selecto/lib/selecto/output/transformers/csv.ex`)
- [x] Configurable quote characters and line endings
- [x] Proper escaping for special characters (embedded newlines, quotes, commas)
- [x] Streaming support for large datasets with consistent behavior
- [x] RFC 4180 compliance with configurable extensions
- [x] Force quote mode and null value customization
- [x] Full test coverage (38/38 tests passing)

### Phase 2: Advanced Features (Future - Optional)
- [ ] Advanced streaming transformer optimizations
- [ ] Custom formatter registration system  
- [ ] Additional export formats (Excel, Parquet, etc.)

### Phase 3: Integration and Polish (Future - Optional)
- [ ] Enhanced Phoenix/LiveView integration helpers
- [ ] Extended Ecto struct compatibility features
- [ ] Advanced pagination support across all formats
- [ ] Performance benchmarking and optimization

## Type Coercion System

### Database Type Mapping
```elixir
type_mappings = %{
  # PostgreSQL -> Elixir
  "integer" => :integer,
  "bigint" => :integer, 
  "smallint" => :integer,
  "decimal" => :decimal,
  "numeric" => :decimal,
  "real" => :float,
  "double precision" => :float,
  "varchar" => :string,
  "text" => :string,
  "char" => :string,
  "boolean" => :boolean,
  "date" => :date,
  "time" => :time,
  "timestamp" => :naive_datetime,
  "timestamptz" => :utc_datetime,
  "json" => :map,
  "jsonb" => :map,
  "array" => :list,
  "uuid" => :uuid
}
```

### Safe Type Coercion
```elixir
# Configurable coercion strategies
coercion_strategies = [
  :strict,      # Raise on coercion errors
  :safe,        # Return string on coercion errors  
  :ignore,      # Skip coercion, return raw values
  :custom       # Use custom coercion functions
]

# Custom coercion functions
custom_coercions = %{
  "money" => &Money.parse/1,
  "geography" => &Geo.PostGIS.decode/1,
  "custom_enum" => &MyApp.Enum.parse/1
}
```

## Integration Examples

### Phoenix LiveView Integration
```elixir
# In LiveView mount/3
def mount(_params, _session, socket) do
  customers = MyApp.Domain.customers()
    |> Selecto.execute(format: {:maps, keys: :atoms})
    |> case do
         {:ok, data} -> data
         {:error, _} -> []
       end
       
  socket = assign(socket, :customers, customers)
  {:ok, socket}
end

# Direct JSON for APIs
def api_customers(conn, params) do
  result = MyApp.Domain.customers()
    |> apply_filters(params)
    |> Selecto.execute(format: {:json, include_meta: true})
    
  case result do
    {:ok, json_string} ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, json_string)
    {:error, reason} ->
      send_error(conn, reason)
  end
end
```

### Ecto Schema Compatibility
```elixir
# Generate Ecto-compatible structs
defmodule Customer do
  use Ecto.Schema
  
  schema "customers" do
    field :name, :string
    field :email, :string
    field :age, :integer
    timestamps()
  end
end

# Execute with Ecto struct format
{:ok, customers} = selecto
  |> Selecto.execute(format: {:ecto_struct, Customer})

# Results are valid Ecto structs that can be used with changesets
changeset = Customer.changeset(List.first(customers), %{name: "Updated Name"})
```

### Streaming for Large Exports
```elixir
# Export millions of records efficiently
defmodule LargeExport do
  def export_customers_to_csv(file_path) do
    MyApp.Domain.all_customers()
    |> Selecto.stream(format: :csv, batch_size: 10_000)
    |> Stream.into(File.stream!(file_path))
    |> Stream.run()
  end
  
  def process_large_dataset do
    MyApp.Domain.transaction_data()
    |> Selecto.stream(format: {:maps, keys: :atoms}, batch_size: 5_000)
    |> Stream.each(fn batch ->
         # Process batch in parallel  
         Task.async_stream(batch, &process_transaction/1)
         |> Stream.run()
       end)
    |> Stream.run()
  end
end
```

## Performance Considerations

### Memory Efficiency
```elixir
# Streaming for memory efficiency
performance_options = [
  {:stream, batch_size: 1000},        # Process in small batches
  {:lazy, transform: :on_demand},     # Transform only when accessed
  {:cursor, prefetch: 500},           # Database cursor with prefetch
  {:compressed, format: :zstd}        # Compress large result sets
]
```

### Type Coercion Performance
- **Atom keys**: Faster map access but memory implications
- **String keys**: Safer for dynamic data, slower access
- **Struct access**: Fastest access, compile-time field validation
- **JSON serialization**: Optimize with streaming for large datasets

### Benchmarking Results (Target)
```elixir
# Performance targets for different formats
benchmarks = %{
  list_of_lists: %{time: "baseline", memory: "baseline"},
  maps_string_keys: %{time: "+15%", memory: "+25%"},
  maps_atom_keys: %{time: "+5%", memory: "+20%"}, 
  structs: %{time: "-5%", memory: "+15%"},
  json_string: %{time: "+30%", memory: "+10%"},
  streaming: %{time: "+10%", memory: "-80%"}
}
```

## Testing Strategy

### Unit Tests
```elixir
test "maps format with atom keys" do
  result = selecto
    |> Selecto.execute(format: {:maps, keys: :atoms})
    
  assert {:ok, [%{name: "John", age: 25} | _]} = result
end

test "struct format with custom struct" do
  result = selecto
    |> Selecto.execute(format: {:structs, Customer})
    
  assert {:ok, [%Customer{name: "John"} | _]} = result
end

test "type coercion preserves data integrity" do
  result = selecto
    |> Selecto.select(["created_at", "total_amount"])
    |> Selecto.execute(format: {:typed_maps, coerce: :all})
    
  [{:ok, [first_row | _]}] = result
  assert %DateTime{} = first_row.created_at
  assert %Decimal{} = first_row.total_amount
end
```

### Performance Tests
```elixir
test "streaming handles large datasets efficiently" do
  # Test with 1M records
  memory_before = :erlang.memory(:total)
  
  selecto
  |> Selecto.stream(format: :maps, batch_size: 1000)
  |> Stream.take(1000)  # Take first 1000 batches (1M records)
  |> Stream.run()
  
  memory_after = :erlang.memory(:total)
  memory_increase = memory_after - memory_before
  
  # Should not increase memory significantly due to streaming
  assert memory_increase < :erlang.memory(:total) * 0.1  # <10% increase
end
```

## Migration Strategy

### Backward Compatibility
```elixir
# Existing code continues to work unchanged
{:ok, {rows, columns, aliases}} = Selecto.execute(selecto)

# New format parameter is optional
{:ok, {rows, columns, aliases}} = Selecto.execute(selecto, format: :raw) # explicit
{:ok, maps} = Selecto.execute(selecto, format: :maps)  # new formats
```

### Migration Helpers
```elixir
# Helper functions for gradual migration
def migrate_to_maps(selecto) do
  case Selecto.execute(selecto, format: :maps) do
    {:ok, maps} -> maps
    {:error, _} ->
      # Fallback to old format
      {:ok, {rows, columns, _aliases}} = Selecto.execute(selecto)
      Enum.map(rows, fn row -> 
        Enum.zip(columns, row) |> Enum.into(%{})
      end)
  end
end
```

## Documentation Requirements

- [ ] Complete API reference for all output formats
- [ ] Migration guide from list-of-lists to other formats
- [ ] Performance comparison and recommendations
- [ ] Integration examples with Phoenix, Ecto, and JSON APIs
- [ ] Type coercion configuration and troubleshooting guide
- [ ] Streaming output patterns for large datasets

## Success Metrics

- [ ] All major output formats supported (maps, structs, JSON, CSV, streaming)
- [ ] Zero breaking changes to existing API
- [ ] Performance overhead <20% for standard formats
- [ ] Memory usage reduction >70% for streaming scenarios
- [ ] Type coercion accuracy >99.5% for supported PostgreSQL types
- [ ] Comprehensive test coverage including edge cases (>95%)