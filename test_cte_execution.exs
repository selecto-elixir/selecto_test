alias SelectoTest.Repo

# Test executing the CTE query
IO.puts("\n=== Testing CTE Execution ===\n")

# The CTE SQL we generated
cte_sql = """
WITH pivot_source AS (
  SELECT DISTINCT j2.film_id 
  FROM actor s 
  JOIN film_actor j1 ON s.actor_id = j1.actor_id 
  JOIN film j2 ON j1.film_id = j2.film_id 
  WHERE s.last_name = 'WITHERSPOON' AND s.first_name = 'ANGELA'
)
SELECT t.description, l.name as language_name
FROM film t 
INNER JOIN pivot_source ps ON t.film_id = ps.film_id
LEFT JOIN language l ON t.language_id = l.language_id
LIMIT 5
"""

IO.puts("Executing CTE query:")
IO.puts(cte_sql)

try do
  result = Ecto.Adapters.SQL.query!(Repo, cte_sql, [])
  
  IO.puts("\n=== Results ===")
  IO.puts("Columns: #{inspect(result.columns)}")
  IO.puts("Rows returned: #{length(result.rows)}")
  
  Enum.each(Enum.take(result.rows, 5), fn row ->
    [description, language] = row
    IO.puts("\n---")
    IO.puts("Description: #{String.slice(description || "", 0, 100)}...")
    IO.puts("Language: #{language}")
  end)
  
  # Compare with the original IN subquery approach
  in_sql = """
  SELECT t.description, l.name as language_name
  FROM film t
  LEFT JOIN language l ON t.language_id = l.language_id
  WHERE t.film_id IN (
    SELECT DISTINCT j2.film_id 
    FROM actor s 
    JOIN film_actor j1 ON s.actor_id = j1.actor_id 
    JOIN film j2 ON j1.film_id = j2.film_id 
    WHERE s.last_name = 'WITHERSPOON' AND s.first_name = 'ANGELA'
  )
  LIMIT 5
  """
  
  IO.puts("\n\n=== Comparison with IN subquery ===")
  IO.puts("Executing IN subquery version...")
  
  in_result = Ecto.Adapters.SQL.query!(Repo, in_sql, [])
  IO.puts("Rows returned: #{length(in_result.rows)}")
  
  # Verify both queries return the same results
  if result.rows == in_result.rows do
    IO.puts("\n✓ Both queries return identical results!")
  else
    IO.puts("\n✗ Results differ between CTE and IN subquery")
  end
  
rescue
  e ->
    IO.puts("\nError executing query:")
    IO.inspect(e)
end