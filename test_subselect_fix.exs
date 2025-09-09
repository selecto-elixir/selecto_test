# Test script for subselect functionality with Jason.decode fix
IO.puts("Testing subselect functionality with Jason.decode fix...")

alias SelectoTest.{Repo, PagilaDomain}

defmodule SubselectTest do
  def analyze_film_data(data) do
    IO.puts("\n  Film data analysis:")
    cond do
      # Already decoded list of maps
      is_list(data) and length(data) > 0 and is_map(hd(data)) ->
        IO.puts("    Type: Already decoded list of maps")
        IO.puts("    Count: #{length(data)} films")
        IO.puts("    First film: #{inspect(hd(data))}")
        
      # JSON string that needs decoding
      is_binary(data) ->
        IO.puts("    Type: JSON string")
        case Jason.decode(data) do
          {:ok, decoded} when is_list(decoded) ->
            IO.puts("    Decoded count: #{length(decoded)} films")
            if length(decoded) > 0 do
              IO.puts("    First film: #{inspect(hd(decoded))}")
            end
          {:error, reason} ->
            IO.puts("    Failed to decode: #{inspect(reason)}")
        end
        
      # Unexpected format
      true ->
        IO.puts("    Type: Unexpected - #{inspect(data)}")
    end
  end
end

# Configure Selecto
domain = PagilaDomain.actors_domain()
selecto = Selecto.configure(domain, Repo)

# Add subselect for films
IO.puts("\n1. Adding film subselect...")
selecto_with_subselect = 
  selecto
  |> Selecto.select(["first_name", "last_name"])
  |> Selecto.subselect([
    %{
      key: "film",
      target_schema: :film,
      fields: ["film_id", "title", "rental_duration", "replacement_cost"],
      format: :json_agg
    }
  ])

# Generate and execute SQL
IO.puts("\n2. Generating SQL...")
{sql, _aliases, params} = Selecto.gen_sql(selecto_with_subselect, [])
IO.puts("SQL: #{sql}")
IO.puts("Params: #{inspect(params)}")

# Execute query
IO.puts("\n3. Executing query...")
case Selecto.Executor.execute(selecto_with_subselect) do
  {:ok, {rows, columns, aliases}} ->
    IO.puts("Success! Got #{length(rows)} rows")
    IO.puts("Columns: #{inspect(columns)}")
    IO.puts("Aliases: #{inspect(aliases)}")
    
    # Check first row format
    if length(rows) > 0 do
      first_row = hd(rows)
      IO.puts("\n4. First row analysis:")
      
      cond do
        is_map(first_row) ->
          IO.puts("  Row format: Map")
          IO.puts("  Keys: #{inspect(Map.keys(first_row))}")
          
          # Check film column
          film_data = Map.get(first_row, "film")
          SubselectTest.analyze_film_data(film_data)
          
        is_list(first_row) ->
          IO.puts("  Row format: List with #{length(first_row)} elements")
          IO.puts("  First 3 values: #{inspect(Enum.take(first_row, 3))}")
          
          # Check last element (likely film data)
          last_elem = List.last(first_row)
          SubselectTest.analyze_film_data(last_elem)
      end
    end
    
  {:error, error} ->
    IO.puts("Query failed!")
    IO.inspect(error, label: "Error")
end

IO.puts("\n5. Test complete!")