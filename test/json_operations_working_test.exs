defmodule JsonOperationsWorkingTest do
  use ExUnit.Case, async: true
  
  describe "JSON Operations Implementation" do
    test "JSON extraction operation can be created" do
      # Create a JSON extraction operation
      json_spec = Selecto.Advanced.JsonOperations.create_json_operation(
        :json_extract,
        "metadata",
        path: "$.category",
        as: "category"
      )
      
      # Verify the spec
      assert json_spec.operation == :json_extract
      assert json_spec.column == "metadata"
      assert json_spec.path == "$.category"
      assert json_spec.alias == "category"
    end
    
    test "JSON aggregation operation can be created" do
      # Create JSON aggregation operation
      json_spec = Selecto.Advanced.JsonOperations.create_json_operation(
        :json_agg,
        "product_name",
        as: "products"
      )
      
      # Verify the spec
      assert json_spec.operation == :json_agg
      assert json_spec.column == "product_name"
      assert json_spec.alias == "products"
    end
    
    test "JSON operations generate SQL" do
      # Create a JSON extraction spec
      json_spec = Selecto.Advanced.JsonOperations.create_json_operation(
        :json_extract,
        "data",
        path: "$.name",
        as: "name"
      )
      
      # Validate the spec (required before SQL generation)
      {:ok, validated_spec} = Selecto.Advanced.JsonOperations.validate_json_operation(json_spec)
      
      # Build SQL for the operation
      sql_iodata = Selecto.Builder.JsonOperations.build_json_select(validated_spec)
      
      # Convert iodata to string for testing
      sql_string = IO.iodata_to_binary(sql_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "data ->"
      assert sql_string =~ "AS"
    end
    
    test "JSON contains operation for filtering" do
      # Create a JSON contains operation
      json_spec = Selecto.Advanced.JsonOperations.create_json_operation(
        :json_contains,
        "metadata",
        value: %{"category" => "electronics"}
      )
      
      # Verify the spec
      assert json_spec.operation == :json_contains
      assert json_spec.column == "metadata"
      assert json_spec.value == %{"category" => "electronics"}
    end
    
    test "JSON path exists operation" do
      # Create a JSON path exists operation
      json_spec = Selecto.Advanced.JsonOperations.create_json_operation(
        :json_path_exists,
        "data",
        path: "$.specs.warranty"
      )
      
      # Verify the spec
      assert json_spec.operation == :json_path_exists
      assert json_spec.column == "data"
      assert json_spec.path == "$.specs.warranty"
    end
  end
  
  describe "JSON Operations in Selecto" do
    test "Selecto supports JSON operations in select" do
      selecto = create_base_selecto("products")
      
      # Create JSON operation spec
      json_spec = Selecto.Advanced.JsonOperations.create_json_operation(
        :json_extract,
        "metadata",
        path: "$.brand",
        as: "brand"
      )
      
      # Add to selecto's selected fields
      result = Map.update(selecto, :set, %{}, fn set ->
        Map.put(set, :selected, ["name", {:json_op, json_spec}])
      end)
      
      # Verify JSON operation was added
      assert is_list(result.set.selected)
      assert {:json_op, _spec} = List.last(result.set.selected)
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