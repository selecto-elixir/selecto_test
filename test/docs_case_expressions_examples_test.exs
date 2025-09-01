defmodule DocsCaseExpressionsExamplesTest do
  use ExUnit.Case, async: true
  
  defp configure_test_selecto do
    domain_config = %{
      root_schema: SelectoTest.Store.Film,
      tables: %{},
      columns: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end

  describe "Simple CASE Expressions from Docs" do
    test "basic value mapping for film ratings" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "film.title",
            {:case, "film.rating",
              when: [
                {"G", "General Audiences"},
                {"PG", "Parental Guidance Suggested"},
                {"PG-13", "Parents Strongly Cautioned"},
                {"R", "Restricted"},
                {"NC-17", "Adults Only"}
              ],
              else: "Not Rated",
              as: "rating_description"
            }
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*film.rating"
      assert sql =~ "WHEN 'G' THEN 'General Audiences'"
      assert sql =~ "WHEN 'PG' THEN 'Parental Guidance Suggested'"
      assert sql =~ "WHEN 'PG-13' THEN 'Parents Strongly Cautioned'"
      assert sql =~ "WHEN 'R' THEN 'Restricted'"
      assert sql =~ "WHEN 'NC-17' THEN 'Adults Only'"
      assert sql =~ "ELSE 'Not Rated'"
      assert sql =~ "AS rating_description"
    end

    test "numeric ranges mapping for prices" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            "product.price",
            {:case, {:expr, "FLOOR(product.price / 100)"},
              when: [
                {0, "Under $100"},
                {1, "$100-$199"},
                {2, "$200-$299"},
                {3, "$300-$399"},
                {4, "$400-$499"}
              ],
              else: "$500+",
              as: "price_range"
            }
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*FLOOR\\(product.price / 100\\)"
      assert sql =~ "WHEN 0 THEN 'Under \\$100'"
      assert sql =~ "WHEN 1 THEN '\\$100-\\$199'"
      assert sql =~ "WHEN 2 THEN '\\$200-\\$299'"
      assert sql =~ "WHEN 3 THEN '\\$300-\\$399'"
      assert sql =~ "WHEN 4 THEN '\\$400-\\$499'"
      assert sql =~ "ELSE '\\$500\\+'"
      assert sql =~ "AS price_range"
    end

    test "NULL handling in simple CASE" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "customer.name",
            {:case, "customer.status",
              when: [
                {"active", "Active Customer"},
                {"inactive", "Inactive"},
                {"pending", "Pending Approval"},
                {nil, "Status Unknown"}  # NULL handling
              ],
              else: "Invalid Status",
              as: "status_label"
            }
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*customer.status"
      assert sql =~ "WHEN 'active' THEN 'Active Customer'"
      assert sql =~ "WHEN 'inactive' THEN 'Inactive'"
      assert sql =~ "WHEN 'pending' THEN 'Pending Approval'"
      assert sql =~ "WHEN NULL THEN 'Status Unknown'"
      assert sql =~ "ELSE 'Invalid Status'"
    end

    test "using COALESCE with CASE" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "order.id",
            {:case, {:coalesce, ["order.priority", 5]},
              when: [
                {1, "Critical"},
                {2, "High"},
                {3, "Medium"},
                {4, "Low"},
                {5, "Normal"}
              ],
              as: "priority_label"
            }
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE.*COALESCE\\(order.priority"
      assert sql =~ "WHEN 1 THEN 'Critical'"
      assert sql =~ "WHEN 2 THEN 'High'"
      assert sql =~ "WHEN 3 THEN 'Medium'"
      assert sql =~ "WHEN 4 THEN 'Low'"
      assert sql =~ "WHEN 5 THEN 'Normal'"
      assert 5 in params
    end
  end

  describe "Searched CASE Expressions from Docs" do
    test "customer tier classification" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "customer.name",
            "total_spent",
            {:case_when, [
                {[{"total_spent", {:>=, 10000}}], "Platinum"},
                {[{"total_spent", {:>=, 5000}}], "Gold"},
                {[{"total_spent", {:>=, 1000}}], "Silver"},
                {[{"total_spent", {:>, 0}}], "Bronze"}
              ],
              else: "Prospect",
              as: "customer_tier"
            }
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "WHEN total_spent >= \\$\\d+ THEN 'Platinum'"
      assert sql =~ "WHEN total_spent >= \\$\\d+ THEN 'Gold'"
      assert sql =~ "WHEN total_spent >= \\$\\d+ THEN 'Silver'"
      assert sql =~ "WHEN total_spent > \\$\\d+ THEN 'Bronze'"
      assert sql =~ "ELSE 'Prospect'"
      assert 10000 in params
      assert 5000 in params
      assert 1000 in params
      assert 0 in params
    end

    test "complex conditions for employee classification" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "employee.name",
            {:case_when, [
                {[
                  {"department", "Sales"},
                  {"years_experience", {:>, 5}},
                  {"performance_rating", {:>=, 4}}
                ], "Senior Sales Expert"},
                {[
                  {"department", "Sales"},
                  {"years_experience", {:>, 2}}
                ], "Sales Professional"},
                {[
                  {"department", "Engineering"},
                  {"level", {:>=, 5}}
                ], "Senior Engineer"},
                {[
                  {"department", "Engineering"}
                ], "Engineer"}
              ],
              else: "Staff",
              as: "role_classification"
            }
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "department = 'Sales'.*AND.*years_experience > \\$\\d+.*AND.*performance_rating >= \\$\\d+"
      assert sql =~ "THEN 'Senior Sales Expert'"
      assert sql =~ "department = 'Sales'.*AND.*years_experience > \\$\\d+"
      assert sql =~ "THEN 'Sales Professional'"
      assert sql =~ "department = 'Engineering'.*AND.*level >= \\$\\d+"
      assert sql =~ "THEN 'Senior Engineer'"
      assert sql =~ "department = 'Engineering'"
      assert sql =~ "THEN 'Engineer'"
      assert sql =~ "ELSE 'Staff'"
    end
  end

  describe "CASE with OR/AND Logic from Docs" do
    test "OR conditions for product grouping" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:case_when, [
                {[{:or, [
                  {"category", "Electronics"},
                  {"category", "Computers"},
                  {"brand", "TechCorp"}
                ]}], "Technology Product"},
                {[{:or, [
                  {"category", "Clothing"},
                  {"category", "Shoes"},
                  {"category", "Accessories"}
                ]}], "Fashion Product"},
                {[true], "Other Product"}
              ],
              as: "product_group"
            }
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "\\(category = 'Electronics' OR category = 'Computers' OR brand = 'TechCorp'\\)"
      assert sql =~ "THEN 'Technology Product'"
      assert sql =~ "\\(category = 'Clothing' OR category = 'Shoes' OR category = 'Accessories'\\)"
      assert sql =~ "THEN 'Fashion Product'"
      assert sql =~ "WHEN true THEN 'Other Product'"
    end

    test "mixed AND/OR for order handling" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "order.id",
            {:case_when, [
                {[{:and, [
                  {"status", "pending"},
                  {:or, [
                    {"priority", 1},
                    {"customer_tier", "Platinum"}
                  ]}
                ]}], "Expedite"},
                {[{"status", "pending"}], "Normal Processing"},
                {[{"status", "completed"}], "Fulfilled"}
              ],
              else: "Review",
              as: "handling_instruction"
            }
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CASE"
      assert sql =~ "status = 'pending' AND \\(priority = 1 OR customer_tier = 'Platinum'\\)"
      assert sql =~ "THEN 'Expedite'"
      assert sql =~ "WHEN status = 'pending' THEN 'Normal Processing'"
      assert sql =~ "WHEN status = 'completed' THEN 'Fulfilled'"
      assert sql =~ "ELSE 'Review'"
    end
  end

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