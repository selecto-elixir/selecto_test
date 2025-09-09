# Test CTE pivot generation with a simpler approach
alias Selecto.Builder.Pivot

defmodule CTETestHelper do
  # Helper function to convert iodata with param markers to SQL string
  def convert_iodata_with_params(iodata, params) do
    params_list = List.wrap(params)
    
    iodata
    |> process_iodata(params_list)
  end

  def process_iodata(iodata, params) when is_list(iodata) do
    Enum.map(iodata, fn item -> process_iodata(item, params) end)
    |> IO.iodata_to_binary()
  end

  def process_iodata({:param, {_op, value}}, _params) do
    "'#{value}'"
  end

  def process_iodata(str, _params) when is_binary(str) do
    str
  end

  def process_iodata(other, _params) do
    to_string(other)
  end
end

IO.puts("\n=== Testing CTE Pivot SQL Generation ===\n")

# Create a minimal selecto structure for testing
selecto = %{
  adapter: Selecto.DB.PostgreSQL,
  domain: %{
    source: %{
      source_table: "actor",
      primary_key: :actor_id,
      fields: [:actor_id, :first_name, :last_name],
      columns: %{
        actor_id: %{type: :integer},
        first_name: %{type: :string},
        last_name: %{type: :string}
      },
      associations: %{
        film_actors: %{
          queryable: :film_actors,
          owner_key: :actor_id,
          related_key: :actor_id
        }
      }
    },
    schemas: %{
      film_actors: %{
        source_table: "film_actor",
        primary_key: :film_id,
        fields: [:film_id, :actor_id],
        associations: %{
          film: %{
            queryable: :film,
            owner_key: :film_id,
            related_key: :film_id
          }
        }
      },
      film: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description, :language_id],
        associations: %{}
      }
    }
  },
  set: %{
    filtered: [
      {"last_name", {"==", "WITHERSPOON"}},
      {"first_name", {"==", "ANGELA"}}
    ]
  }
}

# Create a pivot config for CTE strategy
pivot_config = %{
  target_schema: :film,
  join_path: [:film_actors, :film],
  preserve_filters: true,
  subquery_strategy: :cte
}

IO.puts("Testing CTE strategy SQL generation...")

# Build the CTE strategy directly
{from_iodata, where_iodata, params, deps} = Pivot.build_pivot_query(
  Map.put(selecto, :set, Map.put(selecto.set, :pivot_state, pivot_config)),
  []
)

IO.puts("\nFROM clause:")
IO.inspect(from_iodata, label: "FROM")

IO.puts("\nWHERE clause:")
IO.inspect(where_iodata, label: "WHERE")

IO.puts("\nParams:")
IO.inspect(params, label: "Params")

IO.puts("\nDependencies (CTE spec):")
IO.inspect(deps, label: "Deps")

# Check if CTE spec was generated
case deps do
  [{:cte, cte_spec}] ->
    IO.puts("\n=== CTE Spec Generated ===")
    IO.puts("CTE Name: #{cte_spec.name}")
    IO.puts("CTE Columns: #{inspect(cte_spec.columns)}")
    
    # Convert query iodata with params to string
    query_str = cte_spec.query
    |> CTETestHelper.convert_iodata_with_params(cte_spec.params)
    
    IO.puts("CTE Query:")
    IO.puts(query_str)
    
    # Build the WITH clause
    with_clause = [
      "WITH ", cte_spec.name, " AS (\n  ",
      query_str,
      "\n)"
    ]
    
    IO.puts("\n=== Full CTE SQL Preview ===")
    full_sql = IO.iodata_to_binary([
      with_clause, "\n",
      "SELECT t.description, language.name\n",
      "FROM ", from_iodata, "\n",
      "LEFT JOIN language ON t.language_id = language.language_id"
    ])
    
    IO.puts(full_sql)
    
  _ ->
    IO.puts("\nNo CTE spec generated - using standard query")
end