#!/usr/bin/env elixir

# Quick debug script to test join path resolution
Mix.install([
  {:selecto_test, path: "."},
])

# Create selecto instance
selecto = SelectoTest.PagilaDomain.actors_domain()
  |> Selecto.configure(SelectoTest.Repo, validate: false)

# Test join path calculation
IO.puts("=== Testing join path calculation ===")
case Selecto.Pivot.calculate_join_path(selecto, :film) do
  {:ok, path} ->
    IO.puts("Join path from actor to film: #{inspect(path)}")
  {:error, reason} ->
    IO.puts("Error calculating join path: #{reason}")
end

# Check domain structure
IO.puts("\n=== Domain structure ===")
IO.puts("Source associations: #{inspect(Map.keys(selecto.domain.source.associations))}")
IO.puts("Schemas: #{inspect(Map.keys(selecto.domain.schemas))}")

# Check film_actors association
case Map.get(selecto.domain.source.associations, :film_actors) do
  nil ->
    IO.puts("No film_actors association in source")
  assoc ->
    IO.puts("film_actors association: #{inspect(assoc)}")
end

# Check film_actors schema
case Map.get(selecto.domain.schemas, :film_actors) do
  nil ->
    IO.puts("No film_actors schema")
  schema ->
    IO.puts("film_actors schema associations: #{inspect(Map.keys(schema.associations))}")
    film_assoc = Map.get(schema.associations, :film)
    IO.puts("film association in film_actors: #{inspect(film_assoc)}")
end