alias SelectoTest.Repo

# Check if fulltext column exists
result = Repo.query!("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'film' ORDER BY column_name")

IO.puts("\nColumns in film table:")
Enum.each(result.rows, fn [name, type] -> 
  IO.puts("  #{name}: #{type}") 
end)

# Check specifically for fulltext
fulltext_result = Repo.query!("SELECT column_name FROM information_schema.columns WHERE table_name = 'film' AND column_name = 'fulltext'")

if Enum.empty?(fulltext_result.rows) do
  IO.puts("\nFulltext column NOT found in film table")
else
  IO.puts("\nFulltext column EXISTS in film table")
end
