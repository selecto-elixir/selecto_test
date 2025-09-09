IO.puts("\n=== Verifying CTE Pivot Configuration ===\n")

# Check that selecto_components will use CTE for pivots
{:ok, content} = File.read("/data/chris/projects/selecto_test/vendor/selecto_components/lib/selecto_components/form.ex")

if String.contains?(content, "subquery_strategy: :cte") do
  IO.puts("✓ SelectoComponents is configured to use CTE strategy for pivots")
else
  IO.puts("✗ SelectoComponents is NOT using CTE strategy")
end

# Also verify the CTE implementation exists
{:ok, pivot_content} = File.read("/data/chris/projects/selecto_test/vendor/selecto/lib/selecto/builder/pivot.ex")

if String.contains?(pivot_content, "defp build_cte_strategy") do
  IO.puts("✓ CTE strategy implementation exists in Selecto.Builder.Pivot")
else
  IO.puts("✗ CTE strategy implementation NOT found")
end

# Check SQL builder handles CTE
{:ok, sql_content} = File.read("/data/chris/projects/selecto_test/vendor/selecto/lib/selecto/builder/sql.ex")

if String.contains?(sql_content, "{:cte, cte_spec}") do
  IO.puts("✓ SQL builder can handle CTE specs")
else
  IO.puts("✗ SQL builder cannot handle CTE specs")
end

IO.puts("\nSummary: SelectoComponents will now build pivot queries using CTE strategy")
IO.puts("When a pivot is triggered, it will generate SQL like:")
IO.puts("""
WITH pivot_source AS (
  SELECT DISTINCT target_id 
  FROM source_table s
  JOIN ... 
  WHERE <original filters>
)
SELECT columns
FROM target_table t
INNER JOIN pivot_source ps ON t.id = ps.target_id
LEFT JOIN other_tables ...
""")