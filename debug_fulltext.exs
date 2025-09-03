alias SelectoTest.Repo

# Test basic text search directly
IO.puts("\nDirect SQL test:")
result = Repo.query!("SELECT title FROM film WHERE fulltext @@ websearch_to_tsquery('drama') LIMIT 5")
IO.puts("Found #{length(result.rows)} films with 'drama'")
Enum.each(result.rows, fn [title] -> IO.puts("  - #{title}") end)

# Check what the where builder generates
IO.puts("\n\nBuilding filter SQL...")
selecto = %{
  set: %{},
  source_table: "film",
  postgrex_opts: []
}

{joins, iodata, params} = Selecto.Builder.Sql.Where.build(selecto, {"fulltext", {:text_search, "drama"}})
IO.puts("Joins: #{inspect(joins)}")
IO.puts("Iodata: #{inspect(iodata)}")
IO.puts("Params: #{inspect(params)}")

# Finalize to SQL
{sql, final_params} = Selecto.SQL.Params.finalize(iodata)
IO.puts("\nFinal SQL fragment: #{sql}")
IO.puts("Final params: #{inspect(final_params)}")
