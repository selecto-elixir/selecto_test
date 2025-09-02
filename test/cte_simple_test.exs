defmodule CteSimpleTest do
  use ExUnit.Case, async: true
  
  describe "Basic CTE Operations" do
    test "simple CTE generates correct SQL" do
      # Create a CTE specification
      cte_spec = Selecto.Advanced.CTE.create_cte(
        "active_customers",
        fn ->
          # Create a minimal selecto query
          %{
            set: %{
              selected: ["customer_id", "name"],
              filter: [{"active", true}]
            },
            domain: %{},
            config: %{}
          }
        end
      )
      
      # Build CTE definition
      {cte_iodata, params} = Selecto.Builder.CTE.build_cte_definition(cte_spec)
      
      # Finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(cte_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "active_customers AS"
      assert sql_string =~ "SELECT"
      
      # The query builder function would need actual implementation
      # For now we're just testing the CTE builder structure
    end
    
    test "CTE with explicit columns" do
      # Create a CTE specification with columns
      cte_spec = Selecto.Advanced.CTE.create_cte(
        "customer_stats",
        fn ->
          # Create a minimal selecto query
          %{
            set: %{
              selected: ["customer_id", {:count, "*", as: "order_count"}],
              group_by: ["customer_id"]
            },
            domain: %{},
            config: %{}
          }
        end,
        columns: ["customer_id", "order_count"]
      )
      
      # Verify the spec has columns
      assert cte_spec.columns == ["customer_id", "order_count"]
      assert cte_spec.type == :normal
      assert cte_spec.validated == true
    end
    
    test "multiple CTEs with WITH clause" do
      # Create multiple CTE specifications
      cte1 = Selecto.Advanced.CTE.create_cte(
        "filtered_customers",
        fn ->
          %{
            set: %{
              selected: ["customer_id", "name"],
              filter: [{"status", "active"}]
            },
            domain: %{},
            config: %{}
          }
        end
      )
      
      cte2 = Selecto.Advanced.CTE.create_cte(
        "customer_orders",
        fn ->
          %{
            set: %{
              selected: ["customer_id", {:count, "*", as: "total_orders"}],
              group_by: ["customer_id"]
            },
            domain: %{},
            config: %{}
          }
        end
      )
      
      # Build WITH clause for multiple CTEs
      {with_clause_iodata, params} = Selecto.Builder.CTE.build_with_clause([cte1, cte2])
      
      # Finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(with_clause_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "WITH"
      assert sql_string =~ "filtered_customers AS"
      assert sql_string =~ "customer_orders AS"
    end
  end
  
  describe "Recursive CTE Operations" do
    test "recursive CTE specification" do
      # Create a recursive CTE specification
      cte_spec = Selecto.Advanced.CTE.create_recursive_cte(
        "org_hierarchy",
        base_query: fn ->
          %{
            set: %{
              selected: ["employee_id", "name", "manager_id", "0 AS level"],
              filter: [{"manager_id", nil}]
            },
            domain: %{},
            config: %{}
          }
        end,
        recursive_query: fn cte_ref ->
          %{
            set: %{
              selected: ["e.employee_id", "e.name", "e.manager_id", "h.level + 1"],
              from: "employee e",
              joins: [{:inner, cte_ref, on: "e.manager_id = h.employee_id"}]
            },
            domain: %{},
            config: %{}
          }
        end
      )
      
      # Verify the spec
      assert cte_spec.type == :recursive
      assert cte_spec.name == "org_hierarchy"
      assert is_function(cte_spec.base_query, 0)
      assert is_function(cte_spec.recursive_query, 1)
      assert cte_spec.validated == true
    end
    
    test "recursive CTE with WITH RECURSIVE clause" do
      # Create a recursive CTE
      recursive_cte = Selecto.Advanced.CTE.create_recursive_cte(
        "number_series",
        base_query: fn ->
          %{
            set: %{
              selected: ["1 AS n"]
            },
            domain: %{},
            config: %{}
          }
        end,
        recursive_query: fn _cte_ref ->
          %{
            set: %{
              selected: ["n + 1"],
              from: "number_series",
              filter: [{"n", {:<, 10}}]
            },
            domain: %{},
            config: %{}
          }
        end
      )
      
      # Build WITH clause
      {with_clause_iodata, params} = Selecto.Builder.CTE.build_with_clause([recursive_cte])
      
      # Finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(with_clause_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "WITH RECURSIVE"
      assert sql_string =~ "number_series AS"
      assert sql_string =~ "UNION ALL"
    end
  end
  
  describe "CTE Integration with Selecto" do
    test "adding CTEs to Selecto query" do
      # Create a basic selecto instance
      selecto = %{
        set: %{
          selected: ["*"],
          from: "main_table"
        },
        domain: %{},
        config: %{}
      }
      
      # Add a CTE using with_cte
      selecto_with_cte = Selecto.with_cte(
        selecto,
        "temp_data",
        fn ->
          %{
            set: %{
              selected: ["id", "value"],
              from: "source_table",
              filter: [{"active", true}]
            },
            domain: %{},
            config: %{}
          }
        end
      )
      
      # Verify CTE was added
      assert Map.has_key?(selecto_with_cte.set, :ctes)
      assert length(selecto_with_cte.set.ctes) == 1
      cte = hd(selecto_with_cte.set.ctes)
      assert cte.name == "temp_data"
    end
    
    test "adding multiple CTEs with with_ctes" do
      # Create a basic selecto instance
      selecto = %{
        set: %{
          selected: ["*"],
          from: "main_table"
        },
        domain: %{},
        config: %{}
      }
      
      # Create CTE specs
      cte1 = Selecto.Advanced.CTE.create_cte("cte1", fn -> %{set: %{}, domain: %{}, config: %{}} end)
      cte2 = Selecto.Advanced.CTE.create_cte("cte2", fn -> %{set: %{}, domain: %{}, config: %{}} end)
      
      # Add multiple CTEs
      selecto_with_ctes = Selecto.with_ctes(selecto, [cte1, cte2])
      
      # Verify CTEs were added
      assert length(selecto_with_ctes.set.ctes) == 2
      assert Enum.map(selecto_with_ctes.set.ctes, & &1.name) == ["cte1", "cte2"]
    end
  end
end