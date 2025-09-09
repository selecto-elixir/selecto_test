# Test script to verify subselect functionality
# Run with: mix run test_subselect.exs

alias SelectoTest.PagilaDomainFilms
alias SelectoTest.PagilaDomain
alias SelectoTest.Repo

# Set up connection
connection = Repo

IO.puts("\n=== Testing Subselect Functionality ===\n")

# Test 1: Basic subselect with film domain
IO.puts("Test 1: Basic subselect query for films with actors")
IO.puts("=" |> String.duplicate(50))

selecto = Selecto.configure(PagilaDomainFilms.films_domain(), connection)

# Try to create a subselect manually
selecto_with_subselect = selecto
  |> Selecto.select(["film_id", "title"])
  |> Selecto.limit(2)
  
# Add subselect using the subselect function
subselect_config = %{
  fields: ["first_name", "last_name"],
  target_schema: :actor,
  format: :json_agg,
  alias: "actors"
}

IO.puts("Adding subselect config: #{inspect(subselect_config)}")

selecto_with_subselect = Selecto.subselect(selecto_with_subselect, [subselect_config])

IO.puts("\nSubselect configuration in selecto.set:")
IO.inspect(Map.get(selecto_with_subselect.set, :subselected, []))

# Generate SQL to see what's being created
try do
  {sql, params} = Selecto.to_sql(selecto_with_subselect)
  IO.puts("\nGenerated SQL:")
  IO.puts(sql)
  IO.puts("\nSQL Parameters: #{inspect(params)}")
rescue
  e ->
    IO.puts("\nError generating SQL: #{inspect(e)}")
    IO.puts("Stacktrace: #{inspect(__STACKTRACE__)}")
end

# Try to execute
IO.puts("\nExecuting query...")
case Selecto.execute(selecto_with_subselect) do
  {:ok, {rows, columns, aliases}} ->
    IO.puts("Success! Returned #{length(rows)} rows")
    IO.puts("Columns: #{inspect(columns)}")
    IO.puts("Aliases: #{inspect(aliases)}")
    
    if length(rows) > 0 do
      first_row = hd(rows)
      
      # Handle both map and list formats
      {film_id, title, actors_data} = case first_row do
        %{} = map ->
          # Map format
          IO.puts("\nFirst row keys: #{inspect(Map.keys(map))}")
          {Map.get(map, "film_id"), Map.get(map, "title"), Map.get(map, "actors")}
        
        [id, title_val, actors_val] ->
          # List format (what we're getting)
          IO.puts("\nFirst row (list format): film_id=#{id}, title=#{title_val}")
          {id, title_val, actors_val}
        
        _ ->
          IO.puts("\nUnexpected row format: #{inspect(first_row)}")
          {nil, nil, nil}
      end
      
      # Check the actors data
      if actors_data do
        IO.puts("Film: #{title}")
        
        cond do
          is_list(actors_data) and length(actors_data) > 0 and is_map(hd(actors_data)) ->
            # It's already a list of maps
            IO.puts("Actors (#{length(actors_data)} total): #{inspect(actors_data |> Enum.take(3))}")
          
          is_binary(actors_data) ->
            # It's a JSON string, decode it
            case Jason.decode(actors_data) do
              {:ok, decoded} ->
                IO.puts("Decoded actors (#{length(decoded)} actors): #{inspect(decoded |> Enum.take(3))}")
              {:error, reason} ->
                IO.puts("Failed to decode JSON: #{inspect(reason)}")
            end
          
          true ->
            IO.puts("Actors data in unexpected format: #{inspect(actors_data)}")
        end
      else
        IO.puts("No actors data found")
      end
    end
    
  {:error, error} ->
    IO.puts("Error executing query: #{inspect(error)}")
end

IO.puts("\n=== Test Complete ===\n")