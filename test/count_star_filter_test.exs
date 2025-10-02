defmodule CountStarFilterTest do
  use SelectoTest.SelectoCase, async: true

  describe "COUNT(*) with FILTER" do
    test "count(*) with filter does not parameterize the asterisk" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string}
          }
        },
        joins: %{}
      }

      # Use count(*) with a filter
      selecto = Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:count, "*", {"first_name", {"!=", "DAN"}}}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      # The SQL should contain COUNT(*) not COUNT($1)
      assert sql =~ ~r/count\(\*\)/i, "SQL should contain COUNT(*), not COUNT($1)"
      
      # There should only be one parameter (for "DAN"), not two
      assert length(params) == 1, "Should have exactly 1 parameter for 'DAN'"
      assert params == ["DAN"], "Parameter should be 'DAN'"
      
      # Ensure the SQL has the FILTER clause
      assert sql =~ ~r/filter/i, "SQL should contain FILTER clause"
    end

    test "count(*) without filter works correctly" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string}
          }
        },
        joins: %{}
      }

      selecto = Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:count, "*"}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      # Simple COUNT(*)
      assert sql =~ ~r/count\(\*\)/i
      assert params == []
    end
  end
end
