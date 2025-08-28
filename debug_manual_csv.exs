input = "Line 1,\nwith \"quotes\"\r\nand, commas"
IO.puts("Original input: #{inspect(input)}")

# Test needs_quoting
opts = [delimiter: ",", quote_char: "\"", line_ending: "\n"]

# Let me manually call the functions to see what happens
needs_quoting = String.contains?(input, [opts[:delimiter], opts[:quote_char], opts[:line_ending], "\r", "\n", ","])
IO.puts("Needs quoting: #{needs_quoting}")

# Test quote_field
if needs_quoting do
  quote_char = opts[:quote_char]
  escaped_value = String.replace(input, quote_char, quote_char <> quote_char)
  quoted_field = quote_char <> escaped_value <> quote_char
  IO.puts("Escaped value: #{inspect(escaped_value)}")
  IO.puts("Quoted field: #{inspect(quoted_field)}")
  
  # Now put it in a CSV row
  full_row = quoted_field <> ",42" <> "\n"
  IO.puts("Full row: #{inspect(full_row)}")
end