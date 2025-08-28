# Debug script to test field resolution in pivot context
alias SelectoTest.Repo

# Create the selecto with pivot
selecto = SelectoTest.PagilaDomain.actors_domain()
|> Selecto.configure(SelectoTest.Repo, validate: false)
|> Selecto.filter([{"first_name", "PENELOPE"}])
|> Selecto.pivot(:film)
|> Selecto.select(["title"])

IO.inspect("=== Selecto Configuration ===")
IO.inspect(selecto.set, label: "Selecto set")

IO.inspect("=== Pivot State ===")
IO.inspect(Map.get(selecto.set, :pivot_state), label: "Pivot state")

IO.inspect("=== Available Fields ===")
available_fields = Selecto.available_fields(selecto)
IO.inspect(available_fields, label: "Available fields")

IO.inspect("=== Field Resolution Test ===")
# Test resolving "first_name" (should work in pivot context)
case Selecto.resolve_field(selecto, "first_name") do
  {:ok, field_info} ->
    IO.inspect(field_info, label: "first_name resolution")
  {:error, error} ->
    IO.inspect(error, label: "first_name resolution error")
end

# Test resolving "title" (should work in pivot context)
case Selecto.resolve_field(selecto, "title") do
  {:ok, field_info} ->
    IO.inspect(field_info, label: "title resolution")
  {:error, error} ->
    IO.inspect(error, label: "title resolution error")
end

IO.inspect("=== SQL Generation ===")
{sql, params} = Selecto.to_sql(selecto)
IO.inspect(sql, label: "Generated SQL")
IO.inspect(params, label: "Parameters")

IO.inspect("=== Query Execution ===")
case Selecto.execute(selecto) do
  {:ok, {rows, columns, aliases}} ->
    IO.inspect(length(rows), label: "Number of rows returned")
    IO.inspect(rows, label: "Actual rows")
    IO.inspect(columns, label: "Columns")
    IO.inspect(aliases, label: "Aliases")
  {:error, error} ->
    IO.inspect(error, label: "Execution error")
end

IO.inspect("=== Selecto Configuration ===")
IO.inspect(selecto.set, label: "Selecto set")

IO.inspect("=== Pivot State ===")
IO.inspect(Map.get(selecto.set, :pivot_state), label: "Pivot state")

IO.inspect("=== Available Fields ===")
available_fields = Selecto.available_fields(selecto)
IO.inspect(available_fields, label: "Available fields")

IO.inspect("=== Field Resolution Test ===")
# Test resolving "first_name" (should work in pivot context)
case Selecto.resolve_field(selecto, "first_name") do
  {:ok, field_info} ->
    IO.inspect(field_info, label: "first_name resolution")
  {:error, error} ->
    IO.inspect(error, label: "first_name resolution error")
end

# Test resolving "title" (should work in pivot context)
case Selecto.resolve_field(selecto, "title") do
  {:ok, field_info} ->
    IO.inspect(field_info, label: "title resolution")
  {:error, error} ->
    IO.inspect(error, label: "title resolution error")
end

IO.inspect("=== SQL Generation ===")
{sql, params} = Selecto.to_sql(selecto)
IO.inspect(sql, label: "Generated SQL")
IO.inspect(params, label: "Parameters")
