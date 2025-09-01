alias Selecto.Advanced.ArrayOperations

# Create a test selecto instance
domain = %{
  name: "Film",
  source: %{
    source_table: "film",
    primary_key: :film_id,
    fields: [:film_id, :title, :rating],
    redact_fields: [],
    columns: %{
      film_id: %{type: :integer},
      title: %{type: :string},
      rating: %{type: :string}
    },
    associations: %{}
  },
  schemas: %{},
  joins: %{}
}

selecto = Selecto.configure(domain, [], validate: false)

# Add a STRING_AGG operation
result = 
  selecto
  |> Selecto.select(["rating"])
  |> Selecto.array_select({:string_agg, "title", delimiter: ", ", as: "title_list"})
  |> Selecto.group_by(["rating"])

IO.inspect(result.set.array_operations, label: "Array Operations")

# Now build the SQL
{sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
IO.puts("\nSQL:\n#{sql}")
IO.inspect(params, label: "\nParams")
