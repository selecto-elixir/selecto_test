defmodule CaseExpressionSimpleTest do
  use ExUnit.Case, async: true

  describe "Simple CASE Expression" do
    test "generates correct SQL for simple CASE" do
      # Create CASE specification
      case_spec = Selecto.Advanced.CaseExpression.create_simple_case(
        "rating",
        [
          {"G", "General"},
          {"PG", "Parental"},
          {"R", "Restricted"}
        ],
        else: "Unknown",
        as: "rating_label"
      )

      # Create a minimal selecto context for testing
      selecto = %{
        source: %{
          fields: [:rating],
          redact_fields: [],
          columns: %{rating: %{type: :string}}
        },
        config: %{
          source: %{
            fields: [:rating],
            redact_fields: [],
            columns: %{rating: %{type: :string}}
          },
          joins: %{},
          columns: %{"rating" => %{name: "rating", field: "rating", requires_join: nil}}
        },
        set: %{}
      }

      # Build SQL directly
      {sql_iodata, _params} = Selecto.Builder.CaseExpression.build_case_for_select(case_spec, selecto)

      # The SQL is iodata with param tokens - finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(sql_iodata)

      # Verify SQL structure
      assert sql_string =~ "CASE rating"
      assert sql_string =~ "WHEN $1 THEN $2"
      assert sql_string =~ "WHEN $3 THEN $4"
      assert sql_string =~ "WHEN $5 THEN $6"
      assert sql_string =~ "ELSE $7"
      assert sql_string =~ "END AS rating_label"

      # Verify parameters
      assert final_params == ["G", "General", "PG", "Parental", "R", "Restricted", "Unknown"]
    end
  end

  describe "Searched CASE Expression" do
    test "generates correct SQL for searched CASE" do
      # Create CASE specification
      case_spec = Selecto.Advanced.CaseExpression.create_searched_case(
        [
          {[{"price", {:>=, 100}}], "Premium"},
          {[{"price", {:>=, 50}}], "Standard"},
          {[{"price", {:>, 0}}], "Budget"}
        ],
        else: "Free",
        as: "price_tier"
      )

      # Build SQL with proper selecto context
      selecto = %{
        set: %{},
        source: %{
          fields: [:price],
          redact_fields: [],
          columns: %{price: %{type: :decimal}}
        },
        domain: %{},
        config: %{
          source: %{
            fields: [:price],
            redact_fields: [],
            columns: %{price: %{type: :decimal}}
          },
          joins: %{},
          columns: %{"price" => %{name: "price", field: "price", requires_join: nil}}
        }
      }
      {sql_iodata, _params} = Selecto.Builder.CaseExpression.build_case_for_select(case_spec, selecto)

      # The SQL is iodata with param tokens - finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(sql_iodata)

      # Verify SQL structure
      assert sql_string =~ "CASE"
      assert sql_string =~ "selecto_root.price >= $1"
      assert sql_string =~ "selecto_root.price >= $3"
      assert sql_string =~ "selecto_root.price > $5"
      assert sql_string =~ "ELSE $7"
      assert sql_string =~ "END AS price_tier"

      # Verify parameters
      assert final_params == [100, "Premium", 50, "Standard", 0, "Budget", "Free"]
    end

    test "handles complex conditions with AND/OR" do
      # Create CASE specification with complex conditions
      case_spec = Selecto.Advanced.CaseExpression.create_searched_case(
        [
          {[{:and, [
            {"status", "active"},
            {:or, [
              {"priority", 1},
              {"vip", true}
            ]}
          ]}], "Expedite"},
          {[{"status", "active"}], "Normal"},
          {[{"status", "completed"}], "Done"}
        ],
        else: "Pending",
        as: "handling"
      )

      # Build SQL with proper selecto context
      selecto = %{
        set: %{},
        source: %{
          fields: [:status, :priority, :vip],
          redact_fields: [],
          columns: %{
            status: %{type: :string},
            priority: %{type: :integer},
            vip: %{type: :boolean}
          }
        },
        domain: %{},
        config: %{
          source: %{
            fields: [:status, :priority, :vip],
            redact_fields: [],
            columns: %{
              status: %{type: :string},
              priority: %{type: :integer},
              vip: %{type: :boolean}
            }
          },
          joins: %{},
          columns: %{
            "status" => %{name: "status", field: "status", requires_join: nil},
            "priority" => %{name: "priority", field: "priority", requires_join: nil},
            "vip" => %{name: "vip", field: "vip", requires_join: nil}
          }
        }
      }
      {sql_iodata, _params} = Selecto.Builder.CaseExpression.build_case_for_select(case_spec, selecto)

      # The SQL is iodata with param tokens - finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(sql_iodata)

      # Verify SQL structure for complex conditions
      assert sql_string =~ "CASE"
      assert sql_string =~ "selecto_root.status = $1"
      assert sql_string =~ "selecto_root.priority = $2"
      assert sql_string =~ "selecto_root.vip = $3"
      assert sql_string =~ "THEN $4"
      assert sql_string =~ "selecto_root.status = $5"
      assert sql_string =~ "selecto_root.status = $7"
      assert sql_string =~ "ELSE $9"
      assert sql_string =~ "END AS handling"

      # Verify parameters
      assert final_params == ["active", 1, true, "Expedite", "active", "Normal", "completed", "Done", "Pending"]
    end
  end
end
