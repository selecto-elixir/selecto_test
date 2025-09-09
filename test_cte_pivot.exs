alias SelectoTest.Repo
alias SelectoTest.Store.Actor
alias SelectoTest.PagilaDomain

# Test CTE pivot generation
IO.puts("\n=== Testing CTE Pivot Strategy ===\n")

# Get domain configuration
domain = SelectoTest.PagilaDomain.actors_domain()

# Create selecto with filters that should trigger pivot
selecto = %{
  source: Actor,
  domain: domain,
  repo: Repo,
  adapter: Selecto.DB.PostgreSQL,
  config: domain,  # Use domain as config
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

# Test pivot using the pivot function directly
IO.puts("Testing pivot with CTE strategy...")
# Use subquery_strategy option for CTE
pivoted = Selecto.Pivot.pivot(selecto, :film, subquery_strategy: :cte)

IO.puts("\nPivoted selecto:")
IO.inspect(pivoted, label: "Pivoted", limit: 3)

pivot_config = get_in(pivoted, [:set, :pivot_state])
if pivot_config do
  IO.puts("\nPivot config generated:")
  IO.inspect(pivot_config, label: "Pivot config")
  
  IO.puts("\nBuilding SQL...")
  # Pass the strategy option to the SQL builder
  sql = Selecto.Builder.Sql.build(pivoted, strategy: :cte)
  IO.puts("\nGenerated SQL:")
  IO.puts(sql)
  
  IO.puts("\nExecuting query...")
  try do
    result = Ecto.Adapters.SQL.query!(Repo, sql, [])
    IO.inspect(result.rows, label: "Results", limit: 5)
  rescue
    e ->
      IO.puts("Error executing query: #{inspect(e)}")
      IO.inspect(e)
  end
else
  IO.puts("No pivot config generated - pivot not applied")
end