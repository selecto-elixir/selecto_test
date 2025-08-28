defmodule SelectoPivotDatabaseTest do
  use SelectoTest.SelectoCase, async: false

  setup_all do
    setup_test_database()
  end

  describe "Pivot with Pagila database - Actor to Film pivot" do
    test "pivot from actor to film with actor filter" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["title", "release_year", "rating"])
      |> Selecto.order_by(["title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          # Should get films that have PENELOPE actors
          assert length(rows) > 0
          
          # Verify we're getting film data, not actor data
          [first_row | _] = rows
          [title, year, rating] = first_row
          
          assert is_binary(title)
          assert is_integer(year) or is_nil(year)
          assert is_binary(rating) or is_nil(rating)
          
          IO.inspect({:pivot_results, "Found #{length(rows)} films with PENELOPE actors"})

        {:error, reason} ->
          flunk("Pivot query failed: #{inspect(reason)}")
      end
    end

    test "pivot with multiple actor filters" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}, {"last_name", "GUINESS"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["title", "description"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          # Should get films for the specific actor PENELOPE GUINESS
          assert length(rows) > 0
          
          IO.inspect({:specific_actor_pivot, "Found #{length(rows)} films for PENELOPE GUINESS"})

        {:error, reason} ->
          flunk("Multi-filter pivot failed: #{inspect(reason)}")
      end
    end

    test "pivot with EXISTS strategy" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "NICK"}])
      |> Selecto.pivot(:film, subquery_strategy: :exists)
      |> Selecto.select(["title", "length"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0
          
          IO.inspect({:exists_strategy, "Found #{length(rows)} films using EXISTS strategy"})

        {:error, reason} ->
          flunk("EXISTS pivot strategy failed: #{inspect(reason)}")
      end
    end

    test "pivot without preserving filters" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])
      |> Selecto.pivot(:film, preserve_filters: false)
      |> Selecto.select(["title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          # Without preserved filters, should get all films
          assert length(rows) > 0
          
          # Should be more films than with preserved filters
          IO.inspect({:no_preserve_filters, "Found #{length(rows)} total films (no filter preservation)"})

        {:error, reason} ->
          flunk("Non-preserving pivot failed: #{inspect(reason)}")
      end
    end
  end

  describe "Pivot with Film domain - Film to Actor pivot" do
    test "pivot from film to actor with rating filter" do
      selecto = create_film_selecto()
      |> Selecto.filter([{"rating", "PG-13"}])
      |> Selecto.pivot(:film_actors)  # Pivot to film_actors junction table
      |> Selecto.select(["actor_id"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0
          
          # Should get actor IDs from PG-13 films
          [first_row | _] = rows
          [actor_id] = first_row
          assert is_integer(actor_id)
          
          IO.inspect({:film_to_actor_pivot, "Found #{length(rows)} actor assignments in PG-13 films"})

        {:error, reason} ->
          flunk("Film to actor pivot failed: #{inspect(reason)}")
      end
    end

    test "complex pivot through multiple tables" do
      # This tests pivoting from film -> film_actor -> actor (if we had that path)
      selecto = create_film_selecto()
      |> Selecto.filter([{"rating", "R"}, {"length", {:gt, 120}}])
      |> Selecto.pivot(:film_actors)
      |> Selecto.select(["actor_id"])
      |> Selecto.order_by([{:desc, "actor_id"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0
          
          IO.inspect({:complex_pivot, "Found #{length(rows)} actors in long R-rated films"})

        {:error, reason} ->
          flunk("Complex pivot failed: #{inspect(reason)}")
      end
    end
  end

  describe "Pivot SQL generation validation" do
    test "generated SQL contains expected pivot structure" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["title"])

      {sql, params} = Selecto.to_sql(selecto)
      
      # Should contain pivot target table
      assert sql =~ "FROM film"
      
      # Should contain subquery structure
      assert sql =~ "IN (" or sql =~ "EXISTS ("
      
      # Should contain original table in subquery
      assert sql =~ "actor"
      
      # Should have parameter for filter
      assert "PENELOPE" in params
      
      IO.inspect({:pivot_sql, sql})
      IO.inspect({:pivot_params, params})
    end

    test "different strategies produce different SQL patterns" do
      base_selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])
      |> Selecto.select(["title"])

      # IN strategy
      in_selecto = base_selecto |> Selecto.pivot(:film, subquery_strategy: :in)
      {in_sql, _} = Selecto.to_sql(in_selecto)

      # EXISTS strategy  
      exists_selecto = base_selecto |> Selecto.pivot(:film, subquery_strategy: :exists)
      {exists_sql, _} = Selecto.to_sql(exists_selecto)

      # Should have different patterns
      assert in_sql =~ "IN ("
      assert exists_sql =~ "EXISTS ("
      
      # Both should work with same base structure
      assert in_sql =~ "FROM film"
      assert exists_sql =~ "FROM film"

      IO.inspect({:in_strategy_sql, in_sql})
      IO.inspect({:exists_strategy_sql, exists_sql})
    end
  end

  # Helper functions
  defp create_selecto do
    SelectoTest.PagilaDomain.actors_domain()
    |> Selecto.configure(SelectoTest.Repo, validate: false)
  end

  defp create_film_selecto do
    SelectoTest.PagilaDomainFilms.films_domain()
    |> Selecto.configure(SelectoTest.Repo, validate: false)
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
    # Ensure database is set up - this should be handled by existing test setup
    :ok
  end
end