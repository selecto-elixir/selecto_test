# Test fulltext search debug
alias SelectoTest.Repo

# Start the app
{:ok, _} = Application.ensure_all_started(:selecto_test)

domain = %{
  source: %{
    source_table: "film",
    primary_key: :film_id,
    fields: [:film_id, :title, :description, :fulltext],
    redact_fields: [],
    columns: %{
      film_id: %{type: :integer},
      title: %{type: :string},
      description: %{type: :text},
      fulltext: %{type: :tsvector}
    },
    associations: %{}
  },
  name: "Film",
  joins: %{},
  schemas: %{},
  fields: %{
    "film_id" => %{name: "film_id", requires_join: [], type: "integer"},
    "title" => %{name: "title", requires_join: [], type: "string"},
    "description" => %{name: "description", requires_join: [], type: "text"},
    "fulltext" => %{name: "fulltext", requires_join: [], type: "tsvector"}
  }
}

selecto = Selecto.configure(domain, Repo)

# Try the text search
query = selecto
|> Selecto.select(["title", "description"])
|> Selecto.filter({"fulltext", {:text_search, "drama"}})

IO.inspect(query, label: "Selecto Query State")

# Try to get the SQL using the internal builder
{sql, _aliases, params} = Selecto.Builder.Sql.build(query, [])
IO.puts("\nGenerated SQL:")
IO.puts(IO.iodata_to_binary(sql))
IO.puts("\nParameters:")
IO.inspect(params)

# Now try to execute it
IO.puts("\nExecuting query...")
result = Selecto.execute(query)
IO.inspect(result, label: "Execution Result")
