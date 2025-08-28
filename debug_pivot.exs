#!/usr/bin/env elixir

# Debug script to test pivot functionality
Mix.install([
  {:postgrex, "~> 0.17"},
  {:ecto_sql, "~> 3.10"}
])

defmodule DebugPivot do
  def run do
    # Connect to database
    {:ok, conn} = Postgrex.start_link(
      hostname: "localhost",
      port: 5432,
      database: "selecto_test_dev",
      username: "postgres",
      password: "postgres"
    )

    IO.puts("=== Testing basic actor-film relationships ===")

    # Test 1: Check if Penelope exists and has films
    {:ok, result} = Postgrex.query(conn, """
      SELECT a.first_name, a.last_name, COUNT(f.film_id) as film_count
      FROM actor a
      JOIN film_actor fa ON a.actor_id = fa.actor_id
      JOIN film f ON fa.film_id = f.film_id
      WHERE a.first_name = 'PENELOPE'
      GROUP BY a.actor_id, a.first_name, a.last_name
    """, [])

    IO.puts("Penelope actors and their film counts:")
    result.rows |> Enum.each(fn [first, last, count] ->
      IO.puts("  #{first} #{last}: #{count} films")
    end)

    # Test 2: Check the pivot subquery logic manually
    IO.puts("\n=== Testing pivot subquery logic ===")

    {:ok, subquery_result} = Postgrex.query(conn, """
      SELECT DISTINCT j_film.film_id AS film_id, j_film.title
      FROM actor s
      INNER JOIN film_actor j_film_actors ON s.actor_id = j_film_actors.actor_id
      INNER JOIN film j_film ON j_film_actors.film_id = j_film.film_id
      WHERE s.first_name = $1
      ORDER BY j_film.title
      LIMIT 5
    """, ["PENELOPE"])

    IO.puts("Films found by subquery for Penelope:")
    subquery_result.rows |> Enum.each(fn [film_id, title] ->
      IO.puts("  #{film_id}: #{title}")
    end)

    # Test 3: Check the full pivot query
    IO.puts("\n=== Testing full pivot query ===")

    {:ok, pivot_result} = Postgrex.query(conn, """
      SELECT t.title, t.release_year, t.rating
      FROM film t
      WHERE t.film_id IN (
        SELECT subq.film_id FROM (
          SELECT DISTINCT j_film.film_id AS film_id
          FROM actor s
          INNER JOIN film_actor j_film_actors ON s.actor_id = j_film_actors.actor_id
          INNER JOIN film j_film ON j_film_actors.film_id = j_film.film_id
          WHERE s.first_name = $1
        ) AS subq
      )
      ORDER BY t.title
      LIMIT 5
    """, ["PENELOPE"])

    IO.puts("Films returned by pivot query:")
    pivot_result.rows |> Enum.each(fn [title, year, rating] ->
      IO.puts("  #{title} (#{year}) - #{rating}")
    end)

    IO.puts("\n=== Summary ===")
    IO.puts("Subquery found #{length(subquery_result.rows)} films")
    IO.puts("Pivot query returned #{length(pivot_result.rows)} films")

    Postgrex.close(conn)
  end
end

DebugPivot.run()
