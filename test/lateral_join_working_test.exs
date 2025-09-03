defmodule LateralJoinWorkingTest do
  use ExUnit.Case, async: true
  
  describe "Lateral Join Implementation" do
    test "lateral join functionality is implemented" do
      # Create a basic selecto instance
      selecto = create_base_selecto("customer")
      
      # Add a lateral join
      result = 
        selecto
        |> Selecto.lateral_join(
            :left,
            fn _base ->
              # Return a configured selecto for the lateral subquery
              %{
                set: %{
                  selected: ["order_id", "order_date", "total"],
                  from: "orders",
                  filter: [{"customer_id", {:ref, "customer.customer_id"}}],
                  order_by: [{"order_date", :desc}],
                  limit: 3
                },
                domain: %{},
                config: %{},
                source: %{}
              }
            end,
            "recent_orders"
          )
      
      # Verify lateral join was added
      assert Map.has_key?(result.set, :lateral_joins)
      assert length(result.set.lateral_joins) == 1
      
      lateral = hd(result.set.lateral_joins)
      assert lateral.alias == "recent_orders"
      assert lateral.join_type == :left
      assert is_function(lateral.subquery_builder, 1)
    end
    
    test "lateral join with table function" do
      selecto = create_base_selecto("film")
      
      # Add a lateral join with table function
      # Note: Table functions should reference columns without table prefix
      result = 
        selecto
        |> Selecto.lateral_join(
            :inner,
            {:unnest, "special_features"},
            "features",
            []
          )
      
      # Verify lateral join was added
      assert Map.has_key?(result.set, :lateral_joins)
      assert length(result.set.lateral_joins) == 1
      
      lateral = hd(result.set.lateral_joins)
      assert lateral.alias == "features"
      assert lateral.join_type == :inner
      assert lateral.table_function == {:unnest, "special_features"}
    end
    
    test "lateral join generates SQL" do
      # Create lateral join spec
      lateral_spec = Selecto.Advanced.LateralJoin.create_lateral_join(
        :left,
        fn _base ->
          %{
            set: %{
              selected: ["rental_id", "rental_date"],
              from: "rental",
              filtered: [{"customer_id", {:ref, "customer.customer_id"}}],
              group_by: [],
              order_by: [{"rental_date", :desc}],
              limit: 5,
              offset: nil
            },
            domain: %{},
            config: %{
              source_table: "rental",
              source: %{
                table: "rental",
                fields: [:rental_id, :rental_date, :customer_id],
                columns: %{
                  rental_id: %{type: :integer},
                  rental_date: %{type: :timestamp},
                  customer_id: %{type: :integer}
                },
                redact_fields: []
              },
              joins: %{},
              columns: %{}
            },
            source: %{
              table: "rental",
              fields: [:rental_id, :rental_date, :customer_id],
              columns: %{
                rental_id: %{type: :integer},
                rental_date: %{type: :timestamp},
                customer_id: %{type: :integer}
              },
              redact_fields: []
            }
          }
        end,
        "recent_rentals"
      )
      
      # Build lateral join SQL
      {sql_iodata, params} = Selecto.Builder.LateralJoin.build_lateral_join(lateral_spec)
      
      # Convert iodata to string for testing
      sql_string = IO.iodata_to_binary(sql_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "LEFT JOIN LATERAL"
      assert sql_string =~ "recent_rentals"
      assert sql_string =~ "ON"
      # Check that params contains a ref to customer_id
      assert {:ref, "customer.customer_id"} in params
    end
  end
  
  # Helper to create a base selecto structure
  defp create_base_selecto(table) do
    %{
      set: %{
        selected: [],
        from: table
      },
      domain: %{},
      config: %{
        source: %{
          table: table,
          fields: [],
          columns: %{},
          redact_fields: []
        },
        joins: %{},
        columns: %{}
      },
      source: %{
        table: table,
        fields: [],
        columns: %{},
        redact_fields: []
      }
    }
  end
end