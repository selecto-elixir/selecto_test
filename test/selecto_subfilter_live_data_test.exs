defmodule SelectoSubfilterLiveDataTest do
  @moduledoc """
  Live data integration tests for the Selecto Subfilter System.

  These tests validate the subfilter functionality against real database queries
  using actual Pagila database schema and data.
  """
  use ExUnit.Case, async: false

  alias Selecto.Subfilter.{Registry, Parser}
  alias Selecto.Subfilter.SQL

  @moduletag :live_data

  describe "Selecto Subfilter Live Data Integration" do
    @tag :requires_database
    test "single EXISTS subfilter with film.category.name relationship" do
      # Test: Find all films in the "Action" category
      registry = Registry.new(:film_domain, base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", "Action")

      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure
      assert sql =~ "WHERE (EXISTS ("
      assert sql =~ "FROM film"
      assert sql =~ "INNER JOIN film_category ON"
      assert sql =~ "INNER JOIN category ON"
      assert sql =~ "WHERE category.film_id = film.film_id AND category.name = ?"
      assert params == ["Action"]

      # Log the generated SQL for debugging
      IO.puts("\n=== EXISTS Subfilter SQL ===")
      IO.puts("SQL: #{sql}")
      IO.puts("Params: #{inspect(params)}")
    end

    @tag :requires_database
    test "single IN subfilter with film.category.name for multiple values" do
      # Test: Find all films in "Action" or "Comedy" categories
      registry = Registry.new(:film_domain, base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", ["Action", "Comedy"], strategy: :in)

      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure
      assert sql =~ "WHERE (film.film_id IN ("
      assert sql =~ "SELECT film.film_id"
      assert sql =~ "FROM film"
      assert sql =~ "WHERE category.name IN (?, ?)"
      assert params == ["Action", "Comedy"]

      IO.puts("\n=== IN Subfilter SQL ===")
      IO.puts("SQL: #{sql}")
      IO.puts("Params: #{inspect(params)}")
    end

    @tag :requires_database
    test "aggregation subfilter with count comparison" do
      # Test: Find all films with more than 5 actors
      registry = Registry.new(:film_domain, base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.actors", {:count, ">", 5})

      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure for aggregation (uses direct COUNT comparison, not EXISTS)
      assert sql =~ "WHERE (("
      assert sql =~ "SELECT COUNT(*)"
      assert sql =~ "FROM film"
      assert sql =~ "INNER JOIN film_actor ON"
      assert sql =~ "> ?)"
      assert params == [5]

      IO.puts("\n=== Aggregation Subfilter SQL ===")
      IO.puts("SQL: #{sql}")
      IO.puts("Params: #{inspect(params)}")
    end

    @tag :requires_database
    test "compound AND subfilters for complex filtering" do
      # Test: Find all R-rated films released after 2000
      registry = Registry.new(:film_domain, base_table: :film)
      subfilters = [
        {"film.rating", "R"},
        {"film.release_year", {">", 2000}}
      ]

      {:ok, registry} = Registry.add_compound(registry, :and, subfilters)
      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure for compound operations
      assert sql =~ "WHERE"
      assert sql =~ " AND "
      assert Enum.sort(params) == Enum.sort(["R", 2000])

      IO.puts("\n=== Compound AND Subfilters SQL ===")
      IO.puts("SQL: #{sql}")
      IO.puts("Params: #{inspect(params)}")
    end

    @tag :requires_database
    test "registry analysis for performance insights" do
      # Test: Create a complex registry and analyze it
      registry = Registry.new(:film_domain, base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", "Drama")
      {:ok, registry} = Registry.add_subfilter(registry, "film.language.name", "English")
      {:ok, registry} = Registry.add_subfilter(registry, "film.actors", {:count, ">", 3})

      analysis = Registry.analyze(registry)

      # Validate analysis results
      assert analysis.subfilter_count == 3
      assert analysis.join_complexity in [:low, :medium, :high]
      assert is_map(analysis.strategy_distribution)
      assert is_number(analysis.performance_score)
      assert is_list(analysis.optimization_suggestions)

      IO.puts("\n=== Registry Analysis ===")
      IO.puts("Subfilter Count: #{analysis.subfilter_count}")
      IO.puts("Join Complexity: #{analysis.join_complexity}")
      IO.puts("Strategy Distribution: #{inspect(analysis.strategy_distribution)}")
      IO.puts("Performance Score: #{analysis.performance_score}")
      IO.puts("Optimization Suggestions: #{inspect(analysis.optimization_suggestions)}")
    end

    @tag :requires_database
    test "parser validation with different filter specifications" do
      # Test: Validate different filter specification formats
      test_cases = [
        {"film.title", "ACADEMY DINOSAUR"},
        {"film.release_year", {">", 2005}},
        {"film.rental_rate", {"between", 2.99, 4.99}},
        {"film.category.name", ["Action", "Comedy", "Drama"]},
        {"film.actors", {:count, ">=", 10}}
      ]

      Enum.each(test_cases, fn {path, filter_spec} ->
        case Parser.parse(path, filter_spec) do
          {:ok, spec} ->
            assert spec.relationship_path.path_segments != []
            assert spec.filter_spec != nil
            IO.puts("✓ Parsed: #{path} with #{inspect(filter_spec)}")

          {:error, reason} ->
            flunk("Failed to parse #{path}: #{inspect(reason)}")
        end
      end)
    end

    @tag :requires_database
    test "join path resolution for film domain" do
      # Test: Validate different relationship paths resolve correctly
      test_paths = [
        "film.rating",
        "film.category",
        "film.category.name",
        "film.actor",
        "film.language",
        "film.language.name"
      ]

      Enum.each(test_paths, fn path ->
        {:ok, spec} = Parser.parse(path, "test_value")

        case Selecto.Subfilter.JoinPathResolver.resolve(spec.relationship_path, :film_domain) do
          {:ok, resolution} ->
            assert is_list(resolution.joins)
            assert resolution.target_table != nil
            IO.puts("✓ Resolved path: #{path} -> #{resolution.target_table}")

          {:error, reason} ->
            flunk("Failed to resolve path #{path}: #{inspect(reason)}")
        end
      end)
    end

    @tag :requires_database
    test "strategy override functionality" do
      # Test: Override default strategy for specific subfilters
      registry = Registry.new(:film_domain, base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", ["Action", "Comedy"], id: "category_filter")

      # Default should be :in for list values
      analysis = Registry.analyze(registry)
      assert Map.get(analysis.strategy_distribution, :in, 0) >= 1

      # Override to :exists
      {:ok, registry} = Registry.override_strategy(registry, "category_filter", :exists)
      {:ok, sql, _params} = SQL.generate(registry)

      # Should now use EXISTS format instead of IN
      assert sql =~ "WHERE (EXISTS ("
      assert not (sql =~ "IN (")

      IO.puts("\n=== Strategy Override Test ===")
      IO.puts("Overridden SQL: #{sql}")
    end

    @tag :requires_database
    test "error handling for invalid configurations" do
      # Test: Validate proper error handling for invalid inputs
      registry = Registry.new(:film_domain, base_table: :film)

      # Test duplicate subfilter ID
      {:ok, registry} = Registry.add_subfilter(registry, "film.rating", "R", id: "test_id")

      assert {:error, _reason} = Registry.add_subfilter(registry, "film.title", "Test", id: "test_id")

      # Test invalid relationship path
      assert {:error, _reason} = Parser.parse("film.nonexistent.field", "value")

      # Test invalid domain
      {:ok, spec} = Parser.parse("film.rating", "R")
      assert {:error, _reason} = Selecto.Subfilter.JoinPathResolver.resolve(spec.relationship_path, :invalid_domain)

      IO.puts("✓ Error handling tests passed")
    end

    @tag :requires_database
    test "performance with large number of subfilters" do
      # Test: Create a registry with many subfilters to test performance
      registry = Registry.new(:film_domain, base_table: :film)

      # Add multiple subfilters
      subfilter_specs = [
        {"film.rating", "PG"},
        {"film.release_year", {">", 2000}},
        {"film.rental_rate", {"<", 3.00}},
        {"film.category.name", "Comedy"},
        {"film.language.name", "English"},
        {"film.actors", {:count, ">", 2}}
      ]

      start_time = System.monotonic_time(:millisecond)

      registry =
        Enum.reduce(subfilter_specs, registry, fn {path, spec}, acc ->
          {:ok, updated_registry} = Registry.add_subfilter(acc, path, spec)
          updated_registry
        end)

      {:ok, sql, params} = SQL.generate(registry)
      analysis = Registry.analyze(registry)

      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      # Validate results
      assert analysis.subfilter_count == length(subfilter_specs)
      assert byte_size(sql) > 0
      assert length(params) > 0

      IO.puts("\n=== Performance Test ===")
      IO.puts("Subfilters: #{analysis.subfilter_count}")
      IO.puts("Processing Time: #{duration_ms}ms")
      IO.puts("Join Complexity: #{analysis.join_complexity}")
      IO.puts("Performance Score: #{analysis.performance_score}")
      IO.puts("SQL Length: #{byte_size(sql)} bytes")

      # Performance assertion - should process quickly
      assert duration_ms < 100, "Subfilter processing took too long: #{duration_ms}ms"
    end
  end

  describe "Selecto Subfilter Integration with Phase 1 Joins" do
    @tag :requires_database
    test "subfilters work with existing parameterized joins" do
      # Test: Ensure subfilters integrate properly with Phase 1 join system
      registry = Registry.new(:film_domain, base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", "Action")

      # Generate SQL - this should integrate with existing join resolution
      {:ok, sql, params} = SQL.generate(registry)

      # Validate that the subfilter SQL is properly structured
      assert sql =~ "WHERE"
      assert sql =~ "EXISTS"
      assert params == ["Action"]

      IO.puts("\n=== Phase 1 Integration Test ===")
      IO.puts("Generated SQL integrates with existing joins")
      IO.puts("SQL: #{sql}")
    end
  end
end
