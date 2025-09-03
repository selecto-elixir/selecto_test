domain = %{
  source: %{
    source_table: "films", 
    primary_key: :film_id,
    fields: [:film_id, :title, :rating, :rental_rate],
    redact_fields: [],
    columns: %{
      film_id: %{type: :integer},
      title: %{type: :string},
      rating: %{type: :string},
      rental_rate: %{type: :decimal}
    }
  }
}

selecto = Selecto.configure(domain, [], adapter: Selecto.DB.MySQL, validate: false)
|> Selecto.select(["title", "rating", "rental_rate"])
|> Selecto.filter({"rating", "PG-13"})
|> Selecto.order_by([{"title", :asc}])

IO.puts("Selecto structure:")
IO.inspect(selecto, limit: :infinity)

{sql, _aliases, params} = Selecto.gen_sql(selecto, [])
IO.puts("\nGenerated SQL: #{sql}")
IO.puts("Params: #{inspect(params)}")