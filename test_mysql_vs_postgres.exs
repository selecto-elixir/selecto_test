#!/usr/bin/env elixir

# Test SQL generation for both MySQL and PostgreSQL adapters

# Simple domain for testing
domain = %{
  source: %{
    source_table: "films", 
    primary_key: :film_id,
    fields: [:film_id, :title],
    redact_fields: [],
    columns: %{
      film_id: %{type: :integer},
      title: %{type: :string}
    }
  }
}

IO.puts(String.duplicate("=", 60))
IO.puts("Testing MySQL Adapter")
IO.puts(String.duplicate("=", 60))

# Create selecto with MySQL adapter
mysql_selecto = Selecto.configure(domain, [], adapter: Selecto.DB.MySQL, validate: false)
  |> Selecto.select(["film_id", "title"])

# Generate SQL
{mysql_sql, _, _} = Selecto.gen_sql(mysql_selecto, [])

IO.puts("\nMySQL SQL:")
IO.puts(mysql_sql)

# Check for backticks
if String.contains?(mysql_sql, "`selecto_root`") and 
   String.contains?(mysql_sql, "`film_id`") and
   String.contains?(mysql_sql, "`title`") do
  IO.puts("\n✅ MySQL correctly uses backticks for identifiers")
else
  IO.puts("\n❌ MySQL should use backticks for identifiers")
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Testing PostgreSQL Adapter")
IO.puts(String.duplicate("=", 60))

# Create selecto with PostgreSQL adapter
pg_selecto = Selecto.configure(domain, [], adapter: Selecto.DB.PostgreSQL, validate: false)
  |> Selecto.select(["film_id", "title"])

# Generate SQL
{pg_sql, _, _} = Selecto.gen_sql(pg_selecto, [])

IO.puts("\nPostgreSQL SQL:")
IO.puts(pg_sql)

# Check for double quotes
if String.contains?(pg_sql, "\"selecto_root\"") and
   String.contains?(pg_sql, "\"film_id\"") and
   String.contains?(pg_sql, "\"title\"") do
  IO.puts("\n✅ PostgreSQL correctly uses double quotes for identifiers")
else
  IO.puts("\n❌ PostgreSQL should use double quotes for identifiers")
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Summary")
IO.puts(String.duplicate("=", 60))

mysql_correct = String.contains?(mysql_sql, "`")
pg_correct = String.contains?(pg_sql, "\"")

if mysql_correct and pg_correct do
  IO.puts("✅ Both adapters are using correct quoting!")
else
  IO.puts("❌ Issues found with adapter quoting")
end