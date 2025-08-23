#!/usr/bin/env elixir

Mix.install([
  {:selecto_test, path: "."}
])

# Start the application
Application.put_env(:logger, :level, :info)

defmodule DebugColumnTest do
  alias SelectoTest.{Repo, Store.Film}
  
  def run do
    # Check database connection first
    IO.puts("=== DATABASE DEBUG ===")
    films = Repo.all(Film) |> Enum.take(3)
    IO.inspect(films, label: "Films in DB")
    
    # Check what's in film_id 6396 directly
    film_6396 = Repo.get(Film, 6396)
    IO.inspect(film_6396, label: "Film 6396")
    
    # Test domain configuration like the test
    domain = %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description, :release_year, :language_id, 
                :rental_duration, :rental_rate, :length, :replacement_cost, 
                :rating, :special_features, :last_update],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :text},
          release_year: %{type: :integer},
          language_id: %{type: :integer},
          rental_duration: %{type: :integer},
          rental_rate: %{type: :decimal},
          length: %{type: :integer},
          replacement_cost: %{type: :decimal},
          rating: %{type: :string},
          special_features: %{type: {:array, :string}},
          last_update: %{type: :naive_datetime}
        },
        relationships: %{}
      }
    }
    
    IO.puts("=== SELECTO TEST ===")
    
    selecto = Selecto.new(domain, config: [timeout: 10_000])
    IO.inspect(selecto, label: "Selecto initialized")
    
    # Test the exact query from the failing test
    result = selecto
    |> Selecto.select(["title", "rating"])  
    |> Selecto.filter({"film_id", 6396})
    |> Selecto.execute()
    
    IO.inspect(result, label: "Query result")
    
    case result do
      {:ok, {rows, columns, aliases}} ->
        IO.puts("SUCCESS!")
        IO.inspect(rows, label: "Rows")
        IO.inspect(columns, label: "Columns")
        IO.inspect(aliases, label: "Aliases")
        IO.puts("Row count: #{length(rows)}")
      {:error, error} ->
        IO.puts("ERROR!")
        IO.inspect(error, label: "Error details")
    end
  end
end

DebugColumnTest.run()