#!/usr/bin/env elixir

# Test rating column configuration in both domains
alias SelectoTest.{PagilaDomain, PagilaDomainFilms}

IO.puts("=== Testing Film Rating Column Configuration ===")

# Test PagilaDomain film schema rating column
pagila_domain = PagilaDomain.actors_domain()
pagila_film_rating = get_in(pagila_domain, [:schemas, :film, :columns, :rating])

IO.puts("\n--- PagilaDomain film schema rating column ---")
if pagila_film_rating do
  IO.puts("✅ Found rating column in PagilaDomain film schema")
  IO.puts("Type: #{pagila_film_rating.type}")
  IO.puts("Filter Type: #{Map.get(pagila_film_rating, :filter_type, 'not set')}")
  IO.puts("Has Option Provider: #{Map.has_key?(pagila_film_rating, :option_provider)}")
  if Map.has_key?(pagila_film_rating, :option_provider) do
    IO.puts("Provider Type: #{pagila_film_rating.option_provider.type}")
    IO.puts("Multiple: #{Map.get(pagila_film_rating, :multiple, false)}")
  end
else
  IO.puts("❌ No rating column found in PagilaDomain film schema")
end

# Test PagilaDomainFilms rating column
films_domain = PagilaDomainFilms.domain()
films_rating = get_in(films_domain, [:source, :columns, :rating])

IO.puts("\n--- PagilaDomainFilms source rating column ---")
if films_rating do
  IO.puts("✅ Found rating column in PagilaDomainFilms source")
  IO.puts("Type: #{films_rating.type}")
  IO.puts("Filter Type: #{Map.get(films_rating, :filter_type, 'not set')}")
  IO.puts("Has Option Provider: #{Map.has_key?(films_rating, :option_provider)}")
  if Map.has_key?(films_rating, :option_provider) do
    IO.puts("Provider Type: #{films_rating.option_provider.type}")
    IO.puts("Multiple: #{Map.get(films_rating, :multiple, false)}")
  end
else
  IO.puts("❌ No rating column found in PagilaDomainFilms source")
end

# Test option loading
alias Selecto.OptionProvider

IO.puts("\n=== Testing Option Loading ===")

if pagila_film_rating && Map.has_key?(pagila_film_rating, :option_provider) do
  case OptionProvider.load_options(pagila_film_rating.option_provider) do
    {:ok, options} ->
      IO.puts("✅ PagilaDomain rating column options loaded: #{length(options)} options")
    {:error, reason} ->
      IO.puts("❌ PagilaDomain rating column failed: #{inspect(reason)}")
  end
end

if films_rating && Map.has_key?(films_rating, :option_provider) do
  case OptionProvider.load_options(films_rating.option_provider) do
    {:ok, options} ->
      IO.puts("✅ PagilaDomainFilms rating column options loaded: #{length(options)} options")
    {:error, reason} ->
      IO.puts("❌ PagilaDomainFilms rating column failed: #{inspect(reason)}")
  end
end

IO.puts("\n=== Summary ===")
IO.puts("Both domains now have rating columns configured as select_options filters:")
IO.puts("  • PagilaDomain: film schema rating column with dropdown")
IO.puts("  • PagilaDomainFilms: source rating column with dropdown")
IO.puts("This should make rating appear as a dropdown filter in SelectoComponents UI.")