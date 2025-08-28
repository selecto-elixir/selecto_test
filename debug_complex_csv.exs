rows = [["Line 1,\nwith \"quotes\"\r\nand, commas", 42]]
columns = [%{name: "text", type: :string}, %{name: "number", type: :integer}]
aliases = ["text", "number"]

{:ok, csv} = Selecto.Output.Transformers.CSV.transform(rows, columns, aliases)

IO.puts("Full CSV output:")
IO.inspect(csv, label: "CSV")

IO.puts("\nCSV lines:")
lines = String.split(csv, "\n")
Enum.with_index(lines)
|> Enum.each(fn {line, i} ->
  IO.puts("Line #{i}: #{inspect(line)}")
end)

IO.puts("\nTesting line 1:")
line1 = Enum.at(lines, 1)
IO.puts("Line 1: #{inspect(line1)}")
IO.puts("Starts with quote: #{String.starts_with?(line1, "\"")}")
IO.puts("Ends with \",42: #{String.ends_with?(line1, "\",42")}")
IO.puts("Contains \"\"quotes\"\": #{String.contains?(line1, "\"\"quotes\"\"")}")