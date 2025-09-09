alias SelectoTest.Repo
alias SelectoTest.Store.Actor
alias SelectoTest.PagilaDomain

IO.puts("\n=== Testing SelectoComponents CTE Pivot ===\n")

# Get domain configuration
domain = SelectoTest.PagilaDomain.actors_domain()

# Simulate what SelectoComponents does when building a query
# This is similar to what happens in form.ex execute function
selecto = %{
  source: Actor,
  domain: domain,
  config: domain,
  repo: Repo,
  adapter: Selecto.DB.PostgreSQL,
  filters: [
    {"last_name", {"==", "WITHERSPOON"}},
    {"first_name", {"==", "ANGELA"}}
  ],
  order_by: [],
  limit: 10,
  set: %{
    selected: ["film.description", "language.name"],
    filtered: [
      {"last_name", {"==", "WITHERSPOON"}},
      {"first_name", {"==", "ANGELA"}}
    ]
  }
}

# Check if we should pivot (simulating form.ex logic)
selected_columns = ["film.description", "language.name"]
should_pivot = Enum.all?(selected_columns, fn col ->
  String.contains?(col, ".")
end)

IO.puts("Should pivot: #{should_pivot}")

if should_pivot do
  # Simulate the pivot application from form.ex
  target_table = :film
  join_path = [:film_actors, :film]
  
  # Apply the pivot with CTE strategy
  pivot_state = %{
    target_schema: target_table,
    join_path: join_path,
    preserve_filters: true,
    subquery_strategy: :cte  # Using CTE now!
  }
  
  updated_set = selecto.set
  |> Map.put(:pivot_state, pivot_state)
  
  pivoted_selecto = Map.put(selecto, :set, updated_set)
  
  IO.puts("\nPivot state set with CTE strategy")
  IO.inspect(pivot_state, label: "Pivot config")
  
  # Build SQL using Selecto.Builder.Sql
  IO.puts("\nBuilding SQL with CTE pivot...")
  sql = Selecto.Builder.Sql.build(pivoted_selecto, [])
  
  IO.puts("\nGenerated SQL:")
  IO.puts(sql)
  
  # Execute the query
  IO.puts("\nExecuting query...")
  try do
    result = Ecto.Adapters.SQL.query!(Repo, sql, [])
    IO.puts("Results: #{length(result.rows)} rows")
    
    # Show first few results
    Enum.take(result.rows, 3)
    |> Enum.each(fn row ->
      IO.puts("  - #{inspect(row)}")
    end)
  rescue
    e ->
      IO.puts("Error executing query:")
      IO.inspect(e)
  end
else
  IO.puts("No pivot needed")
end