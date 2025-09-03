defmodule CteWorkingTest do
  use ExUnit.Case, async: true
  import SelectoTest.TestHelpers
  
  describe "Working CTE Examples" do
    test "CTE functionality is implemented and working" do
      # Configure a basic selecto instance
      selecto = configure_test_selecto("film")
      
      # Add a CTE - the query builder returns another configured selecto
      result = 
        selecto
        |> Selecto.with_cte("high_rated_films", fn ->
            # Return another configured selecto for the CTE
            configure_test_selecto("film")
            |> Selecto.select(["film_id", "title", "rating"])
            |> Selecto.filter([{"rating", "PG"}])
          end)
        |> Selecto.select(["title", "rating"])
      
      # Verify CTE was added
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 1
      
      cte = hd(result.set.ctes)
      assert cte.name == "high_rated_films"
      assert cte.type == :normal
      assert is_function(cte.query_builder, 0)
    end
    
    test "Multiple CTEs can be added" do
      selecto = configure_test_selecto("film")
      
      # Create CTE specs first
      cte1 = Selecto.Advanced.CTE.create_cte("cte1", fn ->
        configure_test_selecto("film")
        |> Selecto.select(["film_id", "title"])
      end)
      
      cte2 = Selecto.Advanced.CTE.create_cte("cte2", fn ->
        configure_test_selecto("actor") 
        |> Selecto.select(["actor_id", "first_name"])
      end)
      
      # Add multiple CTEs
      result = Selecto.with_ctes(selecto, [cte1, cte2])
      
      # Verify both CTEs were added
      assert length(result.set.ctes) == 2
      assert Enum.map(result.set.ctes, & &1.name) == ["cte1", "cte2"]
    end
    
    test "Recursive CTE can be created" do
      selecto = configure_test_selecto("film")
      
      # Add a recursive CTE
      result = 
        selecto
        |> Selecto.with_recursive_cte("number_series",
            base_query: fn ->
              # Base case - must return a configured selecto
              %{
                set: %{
                  selected: [{:literal, "1 AS n"}]
                },
                domain: %{},
                config: %{},
                source: %{}
              }
            end,
            recursive_query: fn _cte_ref ->
              # Recursive case - must return a configured selecto
              %{
                set: %{
                  selected: [{:literal, "n + 1"}],
                  from: "number_series",
                  filter: [{"n", {:<, 10}}]
                },
                domain: %{},
                config: %{},
                source: %{}
              }
            end
          )
      
      # Verify recursive CTE was added
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 1
      
      cte = hd(result.set.ctes)
      assert cte.name == "number_series"
      assert cte.type == :recursive
      assert is_function(cte.base_query, 0)
      assert is_function(cte.recursive_query, 1)
    end
    
    test "CTE SQL generation includes WITH clause" do
      selecto = configure_test_selecto("film")
      
      # Add a CTE and build SQL
      result = 
        selecto
        |> Selecto.with_cte("test_cte", fn ->
            configure_test_selecto("film")
            |> Selecto.select(["film_id", "title"])
            |> Selecto.filter([{"rating", "G"}])
          end)
        |> Selecto.select(["title"])
      
      # Build SQL - this should include the WITH clause
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      # Verify WITH clause is present
      assert sql =~ "WITH test_cte AS"
      assert sql =~ ~r/select/i
      
      # The filter parameter should be in params
      assert "G" in params
    end
    
    test "Recursive CTE generates WITH RECURSIVE" do
      selecto = configure_test_selecto("film")
      
      # Create a simple recursive CTE 
      result = 
        selecto
        |> Selecto.with_recursive_cte("counter",
            fn ->
              %{
                set: %{
                  selected: [{:literal, "1 AS value"}],
                  from: nil,
                  filtered: [],
                  group_by: [],
                  order_by: [],
                  limit: nil,
                  offset: nil
                },
                domain: %{},
                config: %{},
                source: %{
                  fields: [:value],
                  columns: %{value: %{type: :integer}},
                  redact_fields: []
                }
              }
            end,
            fn _cte ->
              %{
                set: %{
                  selected: [{:literal, "value + 1"}],
                  from: "counter",
                  filtered: [{"value", {:<, 5}}],
                  group_by: [],
                  order_by: [],
                  limit: nil,
                  offset: nil
                },
                domain: %{},
                config: %{
                  source: %{
                    fields: [:value],
                    columns: %{value: %{type: :integer}},
                    redact_fields: []
                  },
                  joins: %{},
                  columns: %{"value" => %{name: "value", field: "value", requires_join: nil}}
                },
                source: %{
                  fields: [:value],
                  columns: %{value: %{type: :integer}},
                  redact_fields: []
                }
              }
            end
          )
        |> Selecto.select(["title"])
      
      # Build SQL
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      # Verify recursive structure
      assert sql =~ "WITH RECURSIVE counter AS"
      assert sql =~ "UNION ALL"
      
      # The filter parameter should be in params
      assert 5 in params
    end
  end
end