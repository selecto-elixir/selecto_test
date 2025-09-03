defmodule DocumentationExamplesTest do
  use ExUnit.Case, async: true
  import SelectoTest.TestHelpers
  
  @moduledoc """
  Tests for documentation examples updated to use actual Selecto API.
  These tests demonstrate correct usage patterns for the current implementation.
  """

  describe "README.md Examples" do
    test "Array Operations - array_agg" do
      selecto = configure_test_selecto("film")
      
      # Note: array_agg with ORDER BY may need specific implementation
      # Currently showing basic array_agg usage
      result = 
        selecto
        |> Selecto.select([
            "rating",
            {:array_agg, "title"}
          ])
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ ~r/array_agg/i
      assert sql =~ ~r/group by/i
    end

    test "JSON Operations - basic json operations" do
      # Skip for now - JSON operations require specific domain setup
      # This would need a table with JSONB columns configured
    end

    @tag :skip
    test "Recursive CTE - organizational hierarchy" do
      # Recursive CTEs are not yet implemented in current API
      # Would require Selecto.with_recursive_cte/3 method
    end

    @tag :skip
    test "LATERAL Join - recent orders per customer" do
      # LATERAL joins are not yet implemented in current API
      # Would require Selecto.lateral_join/3 method
    end

    test "CASE Expression - film rating classification" do
      selecto = configure_test_selecto("film")
      
      result = 
        selecto
        |> Selecto.select([
            "title",
            {:case, [
                {{"rating", "G"}, {:literal, "General Audience"}},
                {{"rating", "PG"}, {:literal, "Parental Guidance"}},
                {{"rating", "PG-13"}, {:literal, "Teens"}},
                {{"rating", "R"}, {:literal, "Restricted"}}
              ],
              {:literal, "Not Rated"}
            }
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ ~r/case/i
      assert sql =~ ~r/when.*rating.*=.*then/i
      # The literal values are parameterized
      assert "General Audience" in params
      assert "Parental Guidance" in params
      assert "Teens" in params
      assert "Restricted" in params
      assert "Not Rated" in params
    end
  end

  describe "Quick Start Example from README" do
    @tag :skip
    test "Combined advanced features example" do
      # This example combines multiple advanced features that are not all
      # available in the current API (CTEs, LATERAL JOINs, etc.)
    end
  end

  describe "Analytics Dashboard Pattern from README" do
    test "Analytics query with aggregates" do
      selecto = configure_test_selecto("rental")
      
      # Demonstrate aggregation capabilities with actual API
      result = 
        selecto
        |> Selecto.select([
            "rental_date",
            {:count, "rental_id"},
            {:sum, "amount"},
            {:avg, "amount"}
          ])
        |> Selecto.group_by(["rental_date"])
        |> Selecto.order_by([{"rental_date", :desc}])
        |> Selecto.limit(10)
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ ~r/count.*rental_id/i
      assert sql =~ ~r/sum.*amount/i
      assert sql =~ ~r/avg.*amount/i
      assert sql =~ ~r/group by.*rental_date/i
      assert sql =~ ~r/order by.*rental_date.*desc/i
      assert sql =~ ~r/limit.*10/i
    end
  end

  describe "Hierarchical Data with Aggregation from README" do
    @tag :skip
    test "Category tree with product counts" do
      # Recursive CTEs and LATERAL joins not yet available in current API
    end
  end

  describe "Dynamic Filtering and Transformation from README" do
    test "Basic filtering with conditions" do
      selecto = configure_test_selecto("film")
      
      result = 
        selecto
        |> Selecto.select(["title", "rating", "rental_rate"])
        |> Selecto.filter([
            {"rating", ["PG", "PG-13"]},
            {"rental_rate", {"<", 5.0}}
          ])
        |> Selecto.order_by(["title"])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ ~r/where/i
      assert sql =~ ~r/rating.*=.*ANY/i
      assert sql =~ ~r/rental_rate.*</
      assert sql =~ ~r/order by.*title/i
      assert ["PG", "PG-13"] in params
      assert 5.0 in params
    end
  end

  describe "Migration Guide Example from README" do
    test "Query using actual Selecto API" do
      selecto = configure_test_selecto("actor")
      
      # Demonstrating actual API capabilities
      result = 
        selecto
        |> Selecto.select([
            "first_name",
            "last_name",
            {:count, "actor_id"}
          ])
        |> Selecto.filter({"last_name", {:like, "S%"}})
        |> Selecto.group_by(["first_name", "last_name"])
        |> Selecto.order_by([{"last_name", :asc}])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ ~r/select/i
      assert sql =~ "first_name"
      assert sql =~ "last_name"
      assert sql =~ ~r/count.*actor_id/i
      assert sql =~ ~r/where.*last_name.*like/i
      assert sql =~ ~r/group by.*first_name.*last_name/i
      assert sql =~ ~r/order by.*last_name.*asc/i
    end
  end
end