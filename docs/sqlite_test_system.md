# SQLite Test System for Selecto

This document describes the SQLite test system that provides a Docker-based SQLite database with Pagila-compatible schema and data for testing the Selecto SQLite adapter.

## Overview

The SQLite test system provides:
- Docker-based SQLite database container
- Pagila-compatible schema adapted for SQLite
- Sample seed data matching PostgreSQL structure
- Web interface for database exploration
- Comprehensive test suite for the SQLite adapter
- Integration tests using Docker containers

## Architecture

### Components

1. **Docker Container** (`docker/sqlite/`)
   - Alpine Linux base with SQLite installed
   - SQLite Web interface for database exploration
   - Persistent volume for database storage

2. **Schema** (`priv/sqlite/schema/init.sql`)
   - Pagila schema adapted for SQLite syntax
   - Uses TEXT with CHECK constraints instead of ENUMs
   - Includes indexes and views matching PostgreSQL version

3. **Seed Data** (`priv/sqlite/data/seed.sql`)
   - Sample data for all Pagila tables
   - Includes actors, films, customers, rentals, etc.
   - Maintains referential integrity

4. **SQLite Adapter** (`vendor/selecto/lib/selecto/adapters/sqlite.ex`)
   - Implements `Selecto.Database.Adapter` behavior
   - Handles SQLite-specific SQL dialect
   - Type conversions between Elixir and SQLite
   - Transaction and savepoint support

5. **Test Suite**
   - Unit tests for adapter functionality (`test/sqlite_adapter_test.exs`)
   - Docker integration tests (`test/sqlite_docker_integration_test.exs`)
   - Performance and compatibility tests

## Getting Started

### Prerequisites

- Docker and Docker Compose installed
- Elixir 1.17+ with Mix
- SQLite3 CLI (for local testing)

### Starting the SQLite Environment

```bash
# Start SQLite Docker containers
./scripts/start_sqlite_docker.sh

# Access web interface
open http://localhost:8080

# Access SQLite CLI
docker exec -it selecto_sqlite_cli sqlite3 /data/pagila.db

# Stop containers
./scripts/stop_sqlite_docker.sh
```

### Running Tests

```bash
# Install dependencies including exqlite
mix deps.get

# Run SQLite adapter unit tests
mix test test/sqlite_adapter_test.exs

# Run Docker integration tests (requires Docker)
mix test test/sqlite_docker_integration_test.exs

# Run all tests
mix test
```

## Docker Services

### `sqlite` Service
- **Purpose**: Main SQLite database with web interface
- **Port**: 8080 (SQLite Web)
- **Database**: `/data/pagila.db`
- **Features**: Auto-initializes with schema and seed data

### `sqlite-cli` Service
- **Purpose**: CLI access container
- **Usage**: `docker exec -it selecto_sqlite_cli sqlite3 /data/pagila.db`
- **Shares**: Same data volume as main service

## SQLite Adapter Features

### Supported Features
- ✅ Common Table Expressions (CTEs)
- ✅ Window Functions
- ✅ JSON operations
- ✅ Full-text search
- ✅ RETURNING clause
- ✅ UPSERT (INSERT OR REPLACE)
- ✅ Transactions and savepoints

### Not Supported
- ❌ Arrays (use JSON instead)
- ❌ Materialized views
- ❌ Schemas (single schema only)
- ❌ Lateral joins

### Type Mappings

| Elixir Type | SQLite Type | Notes |
|-------------|-------------|-------|
| `:id` | `INTEGER` | Auto-increment primary key |
| `:binary_id` | `TEXT` | UUID stored as text |
| `:integer` | `INTEGER` | 64-bit signed integer |
| `:float` | `REAL` | Floating point |
| `:boolean` | `INTEGER` | 0 = false, 1 = true |
| `:string` | `TEXT` | UTF-8 text |
| `:binary` | `BLOB` | Binary data |
| `:date` | `TEXT` | ISO 8601 format |
| `:datetime` | `TEXT` | ISO 8601 with timezone |
| `:json` | `TEXT` | JSON string |
| `:decimal` | `REAL` | Loses precision |

## Test Coverage

### Unit Tests
- Connection management
- Query execution and parameterization
- Prepared statements
- Transaction handling
- SQL dialect functions
- Type encoding/decoding
- Database introspection

### Integration Tests
- Pagila database queries
- Complex joins and CTEs
- Window functions
- Aggregate functions
- Views
- Full-text search
- JSON operations
- Performance with pagination
- NULL handling
- CASE expressions

## Usage with Selecto

```elixir
# Configure Selecto to use SQLite adapter
config = [
  adapter: Selecto.Adapters.SQLite,
  database: "/path/to/database.db"
]

# Connect
{:ok, conn} = Selecto.Adapters.SQLite.connect(config)

# Execute queries
{:ok, result} = Selecto.Adapters.SQLite.execute(
  conn,
  "SELECT * FROM film WHERE rating = ?1",
  ["PG"],
  []
)

# Use transactions
Selecto.Adapters.SQLite.transaction(conn, fn ->
  # Your transactional code here
end)
```

## Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose -f docker-compose.sqlite.yml logs

# Rebuild containers
docker-compose -f docker-compose.sqlite.yml build --no-cache
```

### Database not initialized
```bash
# Manually initialize
docker exec selecto_sqlite_cli sqlite3 /data/pagila.db < priv/sqlite/schema/init.sql
docker exec selecto_sqlite_cli sqlite3 /data/pagila.db < priv/sqlite/data/seed.sql
```

### Tests failing
```bash
# Ensure exqlite is installed
mix deps.get

# Check SQLite3 is available locally
which sqlite3

# For integration tests, ensure Docker is running
docker ps
```

## Development

### Adding New Features

1. Update adapter in `vendor/selecto/lib/selecto/adapters/sqlite.ex`
2. Add tests in `test/sqlite_adapter_test.exs`
3. Update capability matrix in `supports?/1` and `capabilities/0`
4. Document changes in this README

### Schema Changes

1. Update `priv/sqlite/schema/init.sql`
2. Update seed data in `priv/sqlite/data/seed.sql`
3. Rebuild Docker container
4. Update tests as needed

## Performance Considerations

- SQLite is single-writer, multiple-reader
- Best for read-heavy workloads
- Use WAL mode for better concurrency
- Consider connection pooling for production
- Indexes are crucial for query performance
- VACUUM periodically to maintain performance

## Security Notes

- Always use parameterized queries
- Enable foreign key constraints
- Use PRAGMA secure_delete for sensitive data
- Consider encryption with SQLCipher for production
- Limit database file permissions

## Future Enhancements

- [ ] Connection pooling support
- [ ] WAL mode configuration
- [ ] SQLCipher encryption support
- [ ] Backup/restore utilities
- [ ] Migration from PostgreSQL tool
- [ ] Performance benchmarking suite
- [ ] Streaming query support
- [ ] Batch insert optimization