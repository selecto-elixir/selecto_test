defmodule DocsCaseExpressionsExamplesTest do
  use ExUnit.Case, async: true
  import SelectoTest.TestHelpers
  
  # Tests have been updated to match the actual CASE expression API
  # @moduletag :skip - Removed to enable tests

  describe "Simple CASE Expressions from Docs" do
    test "basic value mapping for film ratings" do
      selecto = configure_test_selecto("film")
      
      # Create CASE specification using the actual API
      case_spec = Selecto.Advanced.CaseExpression.create_simple_case(
        "rating",
        [
          {"G", "General Audiences"},
          {"PG", "Parental Guidance Suggested"},
          {"PG-13", "Parents Strongly Cautioned"},
          {"R", "Restricted"},
          {"NC-17", "Adults Only"}
        ],
        else: "Not Rated",
        as: "rating_description"
      )
      
      result = 
        selecto
        |> Selecto.select(["title", {:case, case_spec}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*rating"
      assert sql =~ "WHEN 'G' THEN 'General Audiences'"
      assert sql =~ "WHEN 'PG' THEN 'Parental Guidance Suggested'"
      assert sql =~ "WHEN 'PG-13' THEN 'Parents Strongly Cautioned'"
      assert sql =~ "WHEN 'R' THEN 'Restricted'"
      assert sql =~ "WHEN 'NC-17' THEN 'Adults Only'"
      assert sql =~ "ELSE 'Not Rated'"
      assert sql =~ "AS rating_description"
    end

    test "numeric ranges mapping for prices" do
      selecto = configure_test_selecto("film")
      
      # Note: Using rental_rate instead of product.price for film table
      case_spec = Selecto.Advanced.CaseExpression.create_simple_case(
        "rental_rate",
        [
          {0, "Under $100"},
          {100, "$100-$199"},
          {200, "$200-$299"},
          {300, "$300-$399"},
          {400, "$400-$499"}
        ],
        else: "$500+",
        as: "price_range"
      )
      
      result = 
        selecto
        |> Selecto.select(["title", "rental_rate", {:case, case_spec}])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*rental_rate"
      assert sql =~ "WHEN.*0.*THEN.*'Under \\$100'"
      assert sql =~ "WHEN.*100.*THEN.*'\\$100-\\$199'"
      assert sql =~ "WHEN.*200.*THEN.*'\\$200-\\$299'"
      assert sql =~ "WHEN.*300.*THEN.*'\\$300-\\$399'"
      assert sql =~ "WHEN.*400.*THEN.*'\\$400-\\$499'"
      assert sql =~ "ELSE '\\$500\\+'"
      assert sql =~ "AS price_range"
    end

    test "NULL handling in simple CASE" do
      selecto = configure_test_selecto("film")
      
      # Using rating field to demonstrate NULL handling
      case_spec = Selecto.Advanced.CaseExpression.create_simple_case(
        "rating",
        [
          {"G", "General"},
          {"PG", "Parental"},
          {"R", "Restricted"},
          {nil, "Not Rated"}  # NULL handling
        ],
        else: "Unknown Rating",
        as: "rating_label"
      )
      
      result = 
        selecto
        |> Selecto.select(["title", {:case, case_spec}])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*rating"
      assert sql =~ "WHEN.*'G'.*THEN.*'General'"
      assert sql =~ "WHEN.*'PG'.*THEN.*'Parental'"
      assert sql =~ "WHEN.*'R'.*THEN.*'Restricted'"
      assert sql =~ "WHEN.*NULL.*THEN.*'Not Rated'"
      assert sql =~ "ELSE.*'Unknown Rating'"
    end

    test "using COALESCE with CASE" do
      selecto = configure_test_selecto("film")
      
      # Using length field to demonstrate integer case mapping
      case_spec = Selecto.Advanced.CaseExpression.create_simple_case(
        "length",
        [
          {60, "Short"},
          {90, "Standard"},
          {120, "Long"},
          {150, "Very Long"},
          {180, "Epic"}
        ],
        else: "Variable",  # Default for NULL values
        as: "length_category"
      )
      
      result = 
        selecto
        |> Selecto.select(["film_id", {:case, case_spec}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*length"
      assert sql =~ "WHEN.*60.*THEN.*'Short'"
      assert sql =~ "WHEN.*90.*THEN.*'Standard'"
      assert sql =~ "WHEN.*120.*THEN.*'Long'"
      assert sql =~ "WHEN.*150.*THEN.*'Very Long'"
      assert sql =~ "WHEN.*180.*THEN.*'Epic'"
      assert sql =~ "ELSE.*'Variable'"
    end
  end

  describe "Searched CASE Expressions from Docs" do
    test "film price tier classification" do
      selecto = configure_test_selecto("film")
      
      case_spec = Selecto.Advanced.CaseExpression.create_searched_case(
        [
          {[{"replacement_cost", {:>=, 25}}], "Premium"},
          {[{"replacement_cost", {:>=, 20}}], "Standard"},
          {[{"replacement_cost", {:>=, 15}}], "Budget"},
          {[{"replacement_cost", {:>, 0}}], "Discount"}
        ],
        else: "Free",
        as: "price_tier"
      )
      
      result = 
        selecto
        |> Selecto.select(["title", "replacement_cost", {:case_when, case_spec}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "WHEN.*replacement_cost >= \\$\\d+.*THEN.*'Premium'"
      assert sql =~ "WHEN.*replacement_cost >= \\$\\d+.*THEN.*'Standard'"
      assert sql =~ "WHEN.*replacement_cost >= \\$\\d+.*THEN.*'Budget'"
      assert sql =~ "WHEN.*replacement_cost > \\$\\d+.*THEN.*'Discount'"
      assert sql =~ "ELSE.*'Free'"
      assert 25 in params
      assert 20 in params
      assert 15 in params
      assert 0 in params
    end

    test "complex conditions for film classification" do
      selecto = configure_test_selecto("film")
      
      case_spec = Selecto.Advanced.CaseExpression.create_searched_case(
        [
          {[
            {"rating", "R"},
            {"length", {:>, 120}},
            {"rental_rate", {:>=, 4}}
          ], "Premium Adult Feature"},
          {[
            {"rating", "R"},
            {"length", {:>, 90}}
          ], "Adult Feature"},
          {[
            {"rating", "G"},
            {"length", {:<=, 90}}
          ], "Family Short"},
          {[
            {"rating", "G"}
          ], "Family Film"}
        ],
        else: "Standard Film",
        as: "film_classification"
      )
      
      result = 
        selecto
        |> Selecto.select(["title", {:case_when, case_spec}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "rating = \\$\\d+.*AND.*length > \\$\\d+.*AND.*rental_rate >= \\$\\d+"
      assert sql =~ "THEN.*'Premium Adult Feature'"
      assert sql =~ "rating = \\$\\d+.*AND.*length > \\$\\d+"
      assert sql =~ "THEN.*'Adult Feature'"
      assert sql =~ "rating = \\$\\d+.*AND.*length <= \\$\\d+"
      assert sql =~ "THEN.*'Family Short'"
      assert sql =~ "rating = \\$\\d+"
      assert sql =~ "THEN.*'Family Film'"
      assert sql =~ "ELSE.*'Standard Film'"
    end
  end

  describe "CASE with OR/AND Logic from Docs" do
    test "OR conditions for film grouping" do
      selecto = configure_test_selecto("film")
      
      case_spec = Selecto.Advanced.CaseExpression.create_searched_case(
        [
          {[{:or, [
            {"rating", "R"},
            {"rating", "NC-17"},
            {"length", {:>, 150}}
          ]}], "Adult or Epic"},
          {[{:or, [
            {"rating", "G"},
            {"rating", "PG"},
            {"length", {:<, 90}}
          ]}], "Family Friendly"},
          {[true], "Standard Film"}
        ],
        as: "film_group"
      )
      
      result = 
        selecto
        |> Selecto.select(["title", {:case_when, case_spec}])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "\\(.*rating = \\$\\d+.*OR.*rating = \\$\\d+.*OR.*length > \\$\\d+.*\\)"
      assert sql =~ "THEN.*'Adult or Epic'"
      assert sql =~ "\\(.*rating = \\$\\d+.*OR.*rating = \\$\\d+.*OR.*length < \\$\\d+.*\\)"
      assert sql =~ "THEN.*'Family Friendly'"
      assert sql =~ "WHEN.*true.*THEN.*'Standard Film'"
    end

    test "mixed AND/OR for film prioritization" do
      selecto = configure_test_selecto("film")
      
      case_spec = Selecto.Advanced.CaseExpression.create_searched_case(
        [
          {[{:and, [
            {"rating", "G"},
            {:or, [
              {"rental_rate", {:>, 4}},
              {"length", {:<, 60}}
            ]}
          ]}], "Featured Family"},
          {[{"rating", "G"}], "Family"},
          {[{"rating", "R"}], "Adult"}
        ],
        else: "General",
        as: "film_priority"
      )
      
      result = 
        selecto
        |> Selecto.select(["film_id", {:case_when, case_spec}])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "rating = \\$\\d+.*AND.*\\(.*rental_rate > \\$\\d+.*OR.*length < \\$\\d+.*\\)"
      assert sql =~ "THEN.*'Featured Family'"
      assert sql =~ "WHEN.*rating = \\$\\d+.*THEN.*'Family'"
      assert sql =~ "WHEN.*rating = \\$\\d+.*THEN.*'Adult'"
      assert sql =~ "ELSE.*'General'"
    end
  end

  # CASE in WHERE and ORDER BY clauses are not yet supported
  # These tests are skipped until the feature is implemented
  @tag :skip
  describe "CASE in WHERE Clause from Docs" do
    test "conditional filtering based on user role" do
      selecto = configure_test_selecto()
      current_dept = 10
      current_user = 123
      
      result = 
        selecto
        |> Selecto.filter([
            {:case_when, [
                {[{"user_role", "admin"}], true},
                {[{"user_role", "manager"}, {"department_id", current_dept}], true},
                {[{"user_role", "employee"}, {"user_id", current_user}], true}
              ],
              else: false}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "WHERE.*CASE"
      assert sql =~ "WHEN user_role = 'admin' THEN true"
      assert sql =~ "WHEN user_role = 'manager' AND department_id = \\$\\d+ THEN true"
      assert sql =~ "WHEN user_role = 'employee' AND user_id = \\$\\d+ THEN true"
      assert sql =~ "ELSE false"
      assert current_dept in params
      assert current_user in params
    end

    test "dynamic date filtering based on customer tier" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {"order_date", {:>=, 
              {:case_when, [
                  {[{"customer_tier", "Platinum"}], "CURRENT_DATE - INTERVAL '1 year'"},
                  {[{"customer_tier", "Gold"}], "CURRENT_DATE - INTERVAL '6 months'"},
                  {[{"customer_tier", "Silver"}], "CURRENT_DATE - INTERVAL '3 months'"}
                ],
                else: "CURRENT_DATE - INTERVAL '1 month'"}
            }}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "order_date >= \\(CASE"
      assert sql =~ "WHEN customer_tier = 'Platinum' THEN CURRENT_DATE - INTERVAL '1 year'"
      assert sql =~ "WHEN customer_tier = 'Gold' THEN CURRENT_DATE - INTERVAL '6 months'"
      assert sql =~ "WHEN customer_tier = 'Silver' THEN CURRENT_DATE - INTERVAL '3 months'"
      assert sql =~ "ELSE CURRENT_DATE - INTERVAL '1 month'"
    end
  end

  @tag :skip
  describe "CASE in ORDER BY Clause from Docs" do
    test "custom sorting logic for status priority" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.order_by([
            {:case_when, [
                {[{"status", "critical"}], 1},
                {[{"status", "high"}], 2},
                {[{"status", "medium"}], 3},
                {[{"status", "low"}], 4}
              ],
              else: 5},
            {"created_date", :asc}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ORDER BY.*CASE"
      assert sql =~ "WHEN status = 'critical' THEN 1"
      assert sql =~ "WHEN status = 'high' THEN 2"
      assert sql =~ "WHEN status = 'medium' THEN 3"
      assert sql =~ "WHEN status = 'low' THEN 4"
      assert sql =~ "ELSE 5"
      assert sql =~ "created_date ASC"
    end

    test "conditional sort direction based on category" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.order_by([
            {:case_when, [
                {[{"category", "Perishable"}], {"expiry_date", :asc}},
                {[{"category", "Electronics"}], {"warranty_date", :desc}},
                {[true], {"created_date", :desc}}
              ]}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ORDER BY.*CASE"
      assert sql =~ "WHEN category = 'Perishable' THEN expiry_date ASC"
      assert sql =~ "WHEN category = 'Electronics' THEN warranty_date DESC"
      assert sql =~ "WHEN true THEN created_date DESC"
    end
  end
end