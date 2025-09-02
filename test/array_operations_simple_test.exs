defmodule ArrayOperationsSimpleTest do
  use ExUnit.Case, async: true
  
  describe "Array Aggregation Operations" do
    test "array_agg generates correct SQL" do
      # Create array aggregation spec
      array_spec = Selecto.Advanced.ArrayOperations.create_array_operation(
        :array_agg,
        "title",
        as: "titles"
      )
      
      # Build SQL
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(array_spec, [])
      
      # Finalize to get SQL string
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "ARRAY_AGG(title)"
      assert sql_string =~ "AS titles"
    end
    
    test "array_agg with DISTINCT" do
      # Create array aggregation spec with DISTINCT
      array_spec = Selecto.Advanced.ArrayOperations.create_array_operation(
        :array_agg,
        "rating",
        distinct: true,
        as: "unique_ratings"
      )
      
      # Build SQL
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(array_spec, [])
      
      # Finalize to get SQL string
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "ARRAY_AGG(DISTINCT rating)"
      assert sql_string =~ "AS unique_ratings"
    end
    
    test "array_agg with ORDER BY" do
      # Create array aggregation spec with ORDER BY
      array_spec = Selecto.Advanced.ArrayOperations.create_array_operation(
        :array_agg,
        "title",
        order_by: [{"release_year", :desc}, {"title", :asc}],
        as: "ordered_titles"
      )
      
      # Build SQL
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(array_spec, [])
      
      # Finalize to get SQL string  
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "ARRAY_AGG(title ORDER BY release_year DESC, title ASC)"
      assert sql_string =~ "AS ordered_titles"
    end
    
    test "string_agg with delimiter" do
      # Create string aggregation spec
      array_spec = Selecto.Advanced.ArrayOperations.create_array_operation(
        :string_agg,
        "name",
        delimiter: ", ",
        as: "name_list"
      )
      
      # Build SQL
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(array_spec, [])
      
      # Finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "STRING_AGG(name, $1)"
      assert sql_string =~ "AS name_list"
      assert final_params == [", "]
    end
  end
  
  describe "Array Filter Operations" do
    test "array_contains filter" do
      # Create array filter spec
      filter_spec = Selecto.Advanced.ArrayOperations.create_array_filter(
        :array_contains,
        "tags",
        ["featured", "new"]
      )
      
      # Build SQL with minimal selecto context
      selecto = %{
        set: %{},
        source: %{
          fields: [:tags],
          columns: %{tags: %{type: {:array, :string}}}
        },
        domain: %{},
        config: %{
          source: %{
            fields: [:tags],
            columns: %{tags: %{type: {:array, :string}}},
            redact_fields: []
          },
          joins: %{},
          columns: %{"tags" => %{name: "tags", field: "tags", requires_join: nil}}
        }
      }
      
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(filter_spec, [], selecto)
      
      # Finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure (columns are qualified with table alias)
      assert sql_string =~ "tags" && sql_string =~ "@> $1"
      assert final_params == [["featured", "new"]]
    end
    
    test "array_overlap filter" do
      # Create array filter spec
      filter_spec = Selecto.Advanced.ArrayOperations.create_array_filter(
        :array_overlap,
        "categories",
        ["electronics", "computers"]
      )
      
      # Build SQL with minimal selecto context
      selecto = %{
        set: %{},
        source: %{
          fields: [:categories],
          columns: %{categories: %{type: {:array, :string}}}
        },
        domain: %{},
        config: %{
          source: %{
            fields: [:categories],
            columns: %{categories: %{type: {:array, :string}}},
            redact_fields: []
          },
          joins: %{},
          columns: %{"categories" => %{name: "categories", field: "categories", requires_join: nil}}
        }
      }
      
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(filter_spec, [], selecto)
      
      # Finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure (columns are qualified with table alias)
      assert sql_string =~ "categories" && sql_string =~ "&& $1"
      assert final_params == [["electronics", "computers"]]
    end
  end
  
  describe "Array Size Operations" do
    test "array_length operation" do
      # Create array length spec
      size_spec = Selecto.Advanced.ArrayOperations.create_array_operation(
        :array_length,
        "items",
        dimension: 1,
        as: "item_count"
      )
      
      # Build SQL
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(size_spec, [])
      
      # Finalize to get SQL string
      {sql_string, final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure
      # Note: dimension is inline, not parameterized
      assert sql_string =~ "ARRAY_LENGTH(items, 1)"
      assert sql_string =~ "AS item_count"
      assert final_params == []
    end
    
    test "cardinality operation" do
      # Create cardinality spec
      size_spec = Selecto.Advanced.ArrayOperations.create_array_operation(
        :cardinality,
        "tags",
        as: "tag_count"
      )
      
      # Build SQL
      {sql_iodata, params} = Selecto.Builder.ArrayOperations.build_array_sql(size_spec, [])
      
      # Finalize to get SQL string
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(sql_iodata)
      
      # Verify SQL structure
      assert sql_string =~ "CARDINALITY(tags)"
      assert sql_string =~ "AS tag_count"
    end
  end
end