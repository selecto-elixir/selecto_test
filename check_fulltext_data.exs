alias SelectoTest.Repo

# Check if fulltext column has data
result = Repo.query!("SELECT COUNT(*) as total, COUNT(fulltext) as with_fulltext FROM film")
[[total, with_fulltext]] = result.rows

IO.puts("\nFilm table statistics:")
IO.puts("  Total films: #{total}")
IO.puts("  Films with fulltext data: #{with_fulltext}")

if with_fulltext == 0 do
  IO.puts("\nNo fulltext data found. We need to populate it.")
  
  # Update the fulltext column with tsvector data from title and description
  IO.puts("\nPopulating fulltext column...")
  
  update_result = Repo.query!("""
    UPDATE film 
    SET fulltext = to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, ''))
    WHERE fulltext IS NULL
  """)
  
  IO.puts("Updated #{update_result.num_rows} rows with fulltext data")
  
  # Verify
  verify_result = Repo.query!("SELECT COUNT(fulltext) FROM film WHERE fulltext IS NOT NULL")
  [[count]] = verify_result.rows
  IO.puts("Verified: #{count} films now have fulltext data")
else
  IO.puts("\nFulltext data already exists!")
  
  # Sample search
  sample_result = Repo.query!("SELECT title FROM film WHERE fulltext @@ websearch_to_tsquery('drama') LIMIT 3")
  IO.puts("\nSample search for 'drama':")
  Enum.each(sample_result.rows, fn [title] -> IO.puts("  - #{title}") end)
end
