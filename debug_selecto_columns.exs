#!/usr/bin/env elixir

# Debug what Selecto sees for columns
alias SelectoTest.{PagilaDomain, PagilaDomainFilms}

IO.puts("=== Debugging Selecto Column Definitions ===")

# Test PagilaDomainFilms (films domain)
IO.puts("\n--- Films Domain ---")
films_domain = PagilaDomainFilms.domain()

# Start a Postgrex connection like the LiveView does
repo_config = SelectoTest.Repo.config()
postgrex_opts = [
  username: repo_config[:username],
  password: repo_config[:password],
  hostname: repo_config[:hostname], 
  database: repo_config[:database],
  port: repo_config[:port] || 5432
]

{:ok, db_conn} = Postgrex.start_link(postgrex_opts)

selecto_films = Selecto.configure(films_domain, db_conn)

# Get columns as FilterForms would see them
films_columns = Selecto.columns(selecto_films)
films_filters = Selecto.filters(selecto_films)
rating_column = Map.get(films_columns, "rating")
rating_filter = Map.get(films_filters, "rating")

IO.puts("Films rating column:")
IO.inspect(rating_column, pretty: true)
IO.puts("Films rating filter:")
IO.inspect(rating_filter, pretty: true)

# Test PagilaDomain (actors domain)
IO.puts("\n--- Actors Domain ---")
actors_domain = PagilaDomain.actors_domain()
selecto_actors = Selecto.configure(actors_domain, db_conn)

actors_columns = Selecto.columns(selecto_actors)
actors_filters = Selecto.filters(selecto_actors)
rating_column_actors = Map.get(actors_columns, "rating")
film_rating_column = Map.get(actors_columns, "film[rating]")
film_rating_filter = Map.get(actors_filters, "film[rating]")

IO.puts("Actors rating column:")
IO.inspect(rating_column_actors, pretty: true)
IO.puts("Actors film[rating] column:")
IO.inspect(film_rating_column, pretty: true)
IO.puts("Actors film[rating] filter:")
IO.inspect(film_rating_filter, pretty: true)

IO.puts("\n--- All Available Columns and Filters ---")
IO.puts("Films domain columns: #{inspect(Map.keys(films_columns))}")
IO.puts("Films domain filters: #{inspect(Map.keys(films_filters))}")
IO.puts("Actors domain columns: #{inspect(Map.keys(actors_columns))}")
IO.puts("Actors domain filters: #{inspect(Map.keys(actors_filters))}")

GenServer.stop(db_conn)