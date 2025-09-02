defmodule DocsCaseExpressionsExamplesTest do
  use ExUnit.Case, async: true
  import SelectoTest.TestHelpers
  
  @moduledoc """
  Tests demonstrating CASE expression functionality using the actual Selecto API.
  CASE expressions use the format: {:case, when_clauses, else_clause}
  where when_clauses is a list of {{field, value}, result} tuples.
  """

  describe "Simple CASE Expressions from Docs" do
    test "basic value mapping for film ratings" do
      selecto = configure_test_selecto("film")
      
      # Using the actual {:case, when_clauses, else_clause} format
      result = 
        selecto
        |> Selecto.select([
            "title",
            {:case, [
              {{"rating", "G"}, {:literal, "General Audiences"}},
              {{"rating", "PG"}, {:literal, "Parental Guidance Suggested"}},
              {{"rating", "PG-13"}, {:literal, "Parents Strongly Cautioned"}},
              {{"rating", "R"}, {:literal, "Restricted"}},
              {{"rating", "NC-17"}, {:literal, "Adults Only"}}
            ], {:literal, "Not Rated"}}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "rating.*=.*THEN"
      assert sql =~ "'General Audiences'"
      assert sql =~ "'Parental Guidance Suggested'"
      assert sql =~ "'Parents Strongly Cautioned'"
      assert sql =~ "'Restricted'"
      assert sql =~ "'Adults Only'"
      assert sql =~ "ELSE.*'Not Rated'"
    end

    test "numeric comparison in CASE" do
      selecto = configure_test_selecto("film")
      
      # Using comparison operators in CASE
      result = 
        selecto
        |> Selecto.select([
            "title",
            "length",
            {:case, [
              {{"length", {">", 120}}, {:literal, "Long"}},
              {{"length", {">=", 90}}, {:literal, "Medium"}}
            ], {:literal, "Short"}}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "length.*>.*THEN.*'Long'"
      assert sql =~ "length.*>=.*THEN.*'Medium'"
      assert sql =~ "ELSE.*'Short'"
    end

    test "simple CASE without ELSE clause" do
      selecto = configure_test_selecto("film")
      
      # CASE without ELSE clause - just omit the third argument
      result = 
        selecto
        |> Selecto.select([
            "title",
            {:case, [
              {{"rating", "G"}, {:literal, "Safe for Kids"}},
              {{"rating", "PG"}, {:literal, "Ask Parents"}}
            ]}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "rating.*=.*'G'.*THEN.*'Safe for Kids'"
      assert sql =~ "rating.*=.*'PG'.*THEN.*'Ask Parents'"
      refute sql =~ "ELSE"
    end

    test "CASE with rental rate classification" do
      selecto = configure_test_selecto("film")
      
      # Decimal value comparisons
      result = 
        selecto
        |> Selecto.select([
            "film_id",
            "rental_rate",
            {:case, [
              {{"rental_rate", {">=", 4.99}}, {:literal, "Premium"}},
              {{"rental_rate", {">=", 2.99}}, {:literal, "Standard"}},
              {{"rental_rate", {">=", 0.99}}, {:literal, "Budget"}}
            ], {:literal, "Free"}}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "rental_rate.*>=.*THEN.*'Premium'"
      assert sql =~ "rental_rate.*>=.*THEN.*'Standard'"
      assert sql =~ "rental_rate.*>=.*THEN.*'Budget'"
      assert sql =~ "ELSE.*'Free'"
      # Check that decimal values are in params
      assert Enum.any?(params, fn p -> p == 4.99 or p == 2.99 or p == 0.99 end)
    end
  end

  describe "Complex CASE Expressions" do
    test "film classification by multiple criteria" do
      selecto = configure_test_selecto("film")
      
      # Multiple CASE expressions in one query
      result = 
        selecto
        |> Selecto.select([
            "title",
            {:case, [
              {{"rating", "G"}, {:literal, "Family"}},
              {{"rating", "PG"}, {:literal, "Family"}},
              {{"rating", "PG-13"}, {:literal, "Teen"}},
              {{"rating", "R"}, {:literal, "Adult"}},
              {{"rating", "NC-17"}, {:literal, "Adult"}}
            ], {:literal, "Unrated"}},
            {:case, [
              {{"length", {">", 180}}, {:literal, "Epic"}},
              {{"length", {">", 120}}, {:literal, "Long"}},
              {{"length", {">=", 90}}, {:literal, "Standard"}},
              {{"length", {">=", 60}}, {:literal, "Short"}}
            ], {:literal, "Very Short"}}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      # Should have two CASE statements
      case_count = sql |> String.split("CASE") |> length() |> Kernel.-(1)
      assert case_count == 2
      assert sql =~ "'Family'"
      assert sql =~ "'Teen'"
      assert sql =~ "'Adult'"
      assert sql =~ "'Epic'"
      assert sql =~ "'Long'"
      assert sql =~ "'Standard'"
    end

    test "CASE in aggregation context" do
      selecto = configure_test_selecto("film")
      
      # Using CASE with aggregation
      result = 
        selecto
        |> Selecto.select([
            "rating",
            {:count, "film_id"},
            {:case, [
              {{"rating", ["G", "PG"]}, {:literal, "Family Friendly"}},
              {{"rating", ["PG-13"]}, {:literal, "Teen Appropriate"}},
              {{"rating", ["R", "NC-17"]}, {:literal, "Adult Only"}}
            ], {:literal, "Unknown"}}
          ])
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "COUNT"
      assert sql =~ "GROUP BY"
      assert sql =~ "'Family Friendly'"
      assert sql =~ "'Teen Appropriate'"
      assert sql =~ "'Adult Only'"
    end
  end

  describe "Edge Cases and Special Scenarios" do
    test "CASE with NULL comparisons" do
      selecto = configure_test_selecto("film")
      
      # Testing NULL handling
      result = 
        selecto
        |> Selecto.select([
            "title",
            {:case, [
              {{"special_features", nil}, {:literal, "No Special Features"}},
              {{"special_features", {:not, nil}}, {:literal, "Has Special Features"}}
            ]}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "special_features.*IS NULL.*THEN.*'No Special Features'" or
             sql =~ "special_features.*=.*NULL.*THEN.*'No Special Features'"
      assert sql =~ "'Has Special Features'"
    end

    test "nested value expressions in CASE" do
      selecto = configure_test_selecto("film")
      
      # Using other aggregate functions as results
      result = 
        selecto
        |> Selecto.select([
            "rating",
            {:case, [
              {{"rating", ["G", "PG"]}, {:count, "film_id"}},
              {{"rating", ["R", "NC-17"]}, {:sum, "rental_rate"}}
            ], {:literal, 0}}
          ])
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "COUNT.*film_id" or sql =~ "COUNT"
      assert sql =~ "SUM.*rental_rate" or sql =~ "SUM"
      assert sql =~ "GROUP BY.*rating"
    end
  end

  # Note: CASE in WHERE and ORDER BY clauses are not yet supported
  # These would require extension to the Selecto.filter and Selecto.order_by functions
  @tag :skip
  describe "CASE in WHERE Clause (Future Feature)" do
    test "conditional filtering with CASE" do
      # This functionality is not yet implemented
      # Would require support in Selecto.filter for CASE expressions
    end
  end

  @tag :skip
  describe "CASE in ORDER BY Clause (Future Feature)" do
    test "conditional ordering with CASE" do
      # This functionality is not yet implemented
      # Would require support in Selecto.order_by for CASE expressions
    end
  end
end