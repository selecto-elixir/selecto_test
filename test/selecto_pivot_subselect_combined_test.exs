defmodule SelectoPivotSubselectCombinedTest do
  use ExUnit.Case

  setup_all do
    setup_test_database()
  end

  describe "Combined Pivot and Subselect features" do
    test "pivot from actor to film with actor subselects" do
      # Start with actors, pivot to films, but include actor data as subselects
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])  # Filter actors
      |> Selecto.pivot(:film)                         # Pivot to films
      |> Selecto.select(["film[title]", "film[rating]", "film[release_year]"]) # Film fields
      |> Selecto.subselect([                         # Add film data as subselect
           %{
             fields: ["title", "rating"],
             target_schema: :film,  # Use film schema
             format: :json_agg,
             alias: "film_details"
           }
         ])
      |> Selecto.order_by(["title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          
          # Should have film columns plus film subselect
          assert "title" in columns
          assert "rating" in columns  
          assert "release_year" in columns
          assert "film_details" in columns
          
          [first_row | _] = rows
          [title, rating, year, film_json] = first_row
          
          # Verify we have film data
          assert is_binary(title)
          assert is_binary(rating) or is_nil(rating)
          
          # Verify film subselect contains film data
          if film_json do
            assert is_list(film_json) or is_binary(film_json)
            IO.inspect({:pivot_with_subselect, "Film '#{title}' has details: #{inspect(film_json)}"})
          end
          
          IO.inspect({:combined_test, "Found #{length(rows)} films from PENELOPE filter with actor subselects"})

        {:error, reason} ->
          flunk("Combined pivot+subselect failed: #{inspect(reason)}")
      end
    end

    test "pivot with multiple subselects using different aggregation formats" do
      selecto = create_selecto()
      |> Selecto.filter([{"last_name", "WAHLBERG"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["film[title]", "film[length]"])
      |> Selecto.subselect([
           # JSON aggregation of film details
           %{
             fields: ["title", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "films_json"
           },
           # Count of films
           %{
             fields: ["film_id"],
             target_schema: :film,
             format: :count,
             alias: "film_count"
           },
           # String list of film titles
           %{
             fields: ["title"],
             target_schema: :film,
             format: :string_agg,
             alias: "film_titles",
             separator: ", "
           }
         ])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          
          # Should have all the columns
          expected_columns = ["title", "length", "films_json", "film_count", "film_titles"]
          Enum.each(expected_columns, fn col ->
            assert col in columns, "Missing column: #{col}"
          end)
          
          [first_row | _] = rows
          [title, length, films_json, film_count, film_titles] = first_row
          
          assert is_binary(title)
          assert is_integer(length) or is_nil(length)
          assert is_integer(film_count)
          
          if films_json, do: assert(is_list(films_json) or is_binary(films_json))
          if film_titles, do: assert(is_binary(film_titles))
          
          IO.inspect({:multi_format_subselects, 
            "Film '#{title}' has #{film_count} films: #{film_titles}, JSON: #{inspect(films_json)}"
          })

        {:error, reason} ->
          flunk("Multiple format subselects with pivot failed: #{inspect(reason)}")
      end
    end

    test "pivot with filtered and ordered subselects" do
      # Pivot to films but only show R-rated films in subselects, ordered by year
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "TOM"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["film[title]", "film[rating]"])
      |> Selecto.subselect([
           %{
             fields: ["title", "release_year", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "other_films_by_actors",
             filters: [{"rating", "R"}],  # Only R-rated films
             order_by: [{:desc, :release_year}]
           }
         ])
      |> Selecto.order_by(["title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "other_films_by_actors" in columns
          
          [first_row | _] = rows
          [title, rating, other_films] = first_row
          
          assert is_binary(title)
          
          # other_films should contain R-rated films ordered by year
          if other_films do
            IO.inspect({:filtered_ordered_subselect, 
              "Film '#{title}' (#{rating}) has R-rated films by same actors: #{inspect(other_films)}"
            })
          end

        {:error, reason} ->
          flunk("Filtered/ordered subselect with pivot failed: #{inspect(reason)}")
      end
    end

    test "complex pivot chain with subselects" do
      # More complex scenario: pivot through multiple relationships
      # This tests the limits of the join path resolution
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "JULIA"}, {"last_name", "MCQUEEN"}]) # Specific actor
      |> Selecto.pivot(:film)  # Get their films
      |> Selecto.select(["film[title]", "film[rating]", "film[length]"])
      |> Selecto.subselect([
           # All films by these actors
           %{
             fields: ["title", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "related_films"
           }
         ])
      |> Selecto.filter([{"rating", "PG"}])  # Additional filter on pivot target (films)

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          if length(rows) > 0 do
            assert "related_films" in columns
            
            [first_row | _] = rows
            [title, rating, length, related_films] = first_row
            
            assert rating == "PG"  # Should match our additional filter
            
            IO.inspect({:complex_pivot_subselect, 
              "JULIA MCQUEEN's PG film '#{title}' has related films: #{inspect(related_films)}"
            })
          else
            IO.inspect({:no_results, "No PG films found for JULIA MCQUEEN"})
          end

        {:error, reason} ->
          flunk("Complex pivot+subselect failed: #{inspect(reason)}")
      end
    end

    test "pivot with exists strategy and subselects" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "NICK"}])
      |> Selecto.pivot(:film, subquery_strategy: :exists)  # Use EXISTS instead of IN
      |> Selecto.select(["film[title]", "film[description]"])
      |> Selecto.subselect([
           %{
             fields: ["title"],
             target_schema: :film,
             format: :string_agg,
             alias: "film_titles",
             separator: " & "
           }
         ])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "film_titles" in columns
          
          [first_row | _] = rows
          [title, _description, film_titles] = first_row
          
          # Should include film titles
          if film_titles do
            assert is_binary(film_titles)
            IO.inspect({:exists_with_subselect, 
              "Film '#{title}' (found via EXISTS) has related films: #{film_titles}"
            })
          end

        {:error, reason} ->
          flunk("EXISTS pivot with subselect failed: #{inspect(reason)}")
      end
    end
  end

  describe "SQL generation for combined features" do
    test "combined features produce valid SQL structure" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "TEST"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["film[title]"])
      |> Selecto.subselect([
           %{
             fields: ["title"],
             target_schema: :film,
             format: :json_agg,
             alias: "films"
           }
         ])

      {sql, params} = Selecto.to_sql(selecto)
      
      # Should contain pivot structure (main FROM is film table)
      assert sql =~ "FROM film"
      
      # Should contain pivot subquery (IN or EXISTS)
      assert sql =~ "IN (" or sql =~ "EXISTS ("
      
      # Should contain subselect correlated subquery
      assert sql =~ "json_agg"
      
      # Should have multiple SELECT keywords (main + subqueries)
      select_count = (String.split(sql, "SELECT") |> length()) - 1
      assert select_count >= 2  # At least main SELECT and subselect SELECT
      
      # Should have filter parameter
      assert "TEST" in params
      
      IO.inspect({:combined_sql, sql})
      IO.inspect({:combined_params, params})
    end

    test "complex combined query performance validation" do
      # This test verifies that complex queries are generated without errors
      # Performance would need to be tested separately with EXPLAIN ANALYZE
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])
      |> Selecto.pivot(:film, subquery_strategy: :exists)
      |> Selecto.select(["film[title]", "film[rating]", "film[length]", "film[release_year]"])
      |> Selecto.subselect([
           %{
             fields: ["title", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "all_films",
             order_by: [:title, :rating]
           },
           %{
             fields: ["film_id"],
             target_schema: :film,
             format: :count,
             alias: "film_count"
           }
         ])
      |> Selecto.order_by([{:desc, "release_year"}, "title"])

      {sql, params} = Selecto.to_sql(selecto)
      
      # Should generate without syntax errors
      assert is_binary(sql)
      assert is_list(params)
      
      # Should be reasonably complex query
      assert String.length(sql) > 200  # Complex queries should be substantial
      
      IO.inspect({:performance_test_sql_length, String.length(sql)})
    end
  end

  describe "Error handling in combined scenarios" do
    test "invalid pivot target with subselects" do
      assert_raise ArgumentError, ~r/Invalid pivot configuration/, fn ->
        create_selecto()
        |> Selecto.pivot(:invalid_schema)
        |> Selecto.subselect(["actor[first_name]"])
      end
    end

    test "invalid subselect target with pivot" do
      assert_raise ArgumentError, ~r/Target schema.*not found/, fn ->
        create_selecto()
        |> Selecto.pivot(:film)
        |> Selecto.subselect(["invalid_schema[field]"])
      end
    end
  end

  # Helper functions
  defp create_selecto do
    SelectoTest.PagilaDomain.actors_domain()
    |> Selecto.configure(get_postgrex_opts(), validate: false)
  end

  defp get_postgrex_opts do
    Application.get_env(:selecto_test, SelectoTest.Repo)[:postgrex_opts] || 
      [
        hostname: System.get_env("DB_HOST", "localhost"),
        port: String.to_integer(System.get_env("DB_PORT", "5432")),
        database: System.get_env("DB_NAME", "selecto_test"),
        username: System.get_env("DB_USER", "postgres"),
        password: System.get_env("DB_PASS", "postgres")
      ]
  end

  defp setup_test_database do
    :ok
  end
end