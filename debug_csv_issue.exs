input = [["Smith, John", 25]]
columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
aliases = ["name", "age"]

# Test non-streaming version
{:ok, result} = Selecto.Output.Transformers.CSV.transform(input, columns, aliases, delimiter: ";", quote_char: "'")
IO.puts("Non-streaming result:")
IO.puts(inspect(result))

# Test streaming version
{:ok, stream} = Selecto.Output.Transformers.CSV.stream_transform(input, columns, aliases, delimiter: ";", quote_char: "'")
stream_result = Enum.join(stream, "")
IO.puts("Streaming result:")
IO.puts(inspect(stream_result))

# Compare
IO.puts("Results match: #{result == stream_result}")
