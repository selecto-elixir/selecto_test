#!/usr/bin/env elixir

# Debug script to check pivot data and relationships
require Logger

# Get database connection
opts = [
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  database: System.get_env("DB_NAME", "selecto_test_test"),
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres")
]

{:ok, conn} = Postgrex.start_link(opts)

IO.puts("=== Checking Pagila Data ===")

# Check if tables exist and have data
tables = ["actor", "film", "film_actor"]
for table <- tables do
  case Postgrex.query(conn, "SELECT COUNT(*) FROM #{table}", []) do
    {:ok, result} ->
      [[count]] = result.rows
      IO.puts("✓ #{table}: #{count} rows")
    {:error, error} ->
      IO.puts("✗ #{table}: #{inspect(error)}")
  end
end

IO.puts("\n=== Checking Actor PENELOPE ===")

# Check if PENELOPE exists
case Postgrex.query(conn, "SELECT actor_id, first_name, last_name FROM actor WHERE first_name = $1", ["PENELOPE"]) do
  {:ok, result} ->
    IO.puts("Found #{length(result.rows)} actors named PENELOPE:")
    for [id, first, last] <- result.rows do
      IO.puts("  - #{id}: #{first} #{last}")
    end
  {:error, error} ->
    IO.puts("Error querying actors: #{inspect(error)}")
end

IO.puts("\n=== Checking Film-Actor Relationships ===")

# Check film_actor relationships for PENELOPE
case Postgrex.query(conn, """
  SELECT a.actor_id, a.first_name, a.last_name, COUNT(fa.film_id) as film_count
  FROM actor a
  JOIN film_actor fa ON a.actor_id = fa.actor_id
  WHERE a.first_name = $1
  GROUP BY a.actor_id, a.first_name, a.last_name
  """, ["PENELOPE"]) do
  {:ok, result} ->
    IO.puts("PENELOPE's film relationships:")
    for [id, first, last, count] <- result.rows do
      IO.puts("  - #{id}: #{first} #{last} appears in #{count} films")
    end
  {:error, error} ->
    IO.puts("Error querying film relationships: #{inspect(error)}")
end

IO.puts("\n=== Checking Specific Films for PENELOPE ===")

# Check specific films for PENELOPE
case Postgrex.query(conn, """
  SELECT f.film_id, f.title, f.rating, f.length
  FROM film f
  JOIN film_actor fa ON f.film_id = fa.film_id
  JOIN actor a ON fa.actor_id = a.actor_id
  WHERE a.first_name = $1
  ORDER BY f.title
  LIMIT 5
  """, ["PENELOPE"]) do
  {:ok, result} ->
    IO.puts("Films with PENELOPE:")
    for [id, title, rating, length] <- result.rows do
      IO.puts("  - #{id}: #{title} (#{rating}, #{length}min)")
    end
  {:error, error} ->
    IO.puts("Error querying films: #{inspect(error)}")
end

IO.puts("\n=== Testing Selecto Pivot SQL Generation ===")

# Test the actual Selecto pivot SQL generation
try do
  # Create Selecto instance
  {:ok, selecto_conn} = Postgrex.start_link(opts)
  selecto = SelectoTest.PagilaDomain.actors_domain()
           |> Selecto.configure(selecto_conn, validate: false)
           |> Selecto.filter([{"first_name", "PENELOPE"}])
           |> Selecto.pivot(:film)
           |> Selecto.select(["title"])

  {sql, params} = Selecto.to_sql(selecto)
  IO.puts("Generated SQL:")
  IO.puts(sql)
  IO.puts("Parameters: #{inspect(params)}")

  # Execute the query
  case Selecto.execute(selecto) do
    {:ok, {rows, columns, aliases}} ->
      IO.puts("✓ Query executed successfully: #{length(rows)} rows")
      if length(rows) > 0 do
        IO.puts("First row: #{inspect(hd(rows))}")
      end
    {:error, error} ->
      IO.puts("✗ Query execution failed: #{inspect(error)}")
  end

rescue
  e ->
    IO.puts("Error in Selecto operations: #{inspect(e)}")
end

Postgrex.close(conn)
