#!/usr/bin/env elixir

# Demo: Film rating enum select options
alias Selecto.OptionProvider

IO.puts("=== Film Rating Select Options Demo ===")

# Test with the actual Film schema from our project
film_rating_provider = %{
  type: :enum,
  schema: SelectoTest.Store.Film,
  field: :rating
}

IO.puts("Provider configuration:")
IO.inspect(film_rating_provider, pretty: true)

case OptionProvider.load_options(film_rating_provider) do
  {:ok, options} ->
    IO.puts("\n✅ Successfully loaded MPAA rating options:")
    Enum.each(options, fn {value, display} ->
      IO.puts("  - Value: #{inspect(value)}, Display: #{inspect(display)}")
    end)
    
    IO.puts("\nThese options can be used in:")
    IO.puts("  • SelectoComponents filter dropdowns")
    IO.puts("  • SelectoDome validation")
    IO.puts("  • SelectoKino notebook interfaces")
    
  {:error, reason} ->
    IO.puts("❌ Failed to load options: #{inspect(reason)}")
end

IO.puts("\n=== Validation Demo ===")
case OptionProvider.validate_provider(film_rating_provider) do
  :ok ->
    IO.puts("✅ Provider configuration is valid")
  {:error, reason} ->
    IO.puts("❌ Provider validation failed: #{inspect(reason)}")
end

IO.puts("\n=== Phase 1 Complete ===")
IO.puts("Ready to implement Phase 2: SelectoComponents UI!")