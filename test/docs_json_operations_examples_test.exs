defmodule DocsJsonOperationsExamplesTest do
  use ExUnit.Case, async: true
  
  defp configure_test_selecto do
    domain_config = %{
      root_schema: SelectoTest.Store.Product,
      tables: %{},
      columns: %{},
      filters: []
    }
    
    Selecto.configure(domain_config, :test_connection)
  end

  describe "JSON vs JSONB Examples from Docs" do
    test "working with both JSON types" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            {:json_extract, "config", "$.theme", as: "theme"},      # JSON column
            {:jsonb_extract, "metadata", "$.tags", as: "tags"}      # JSONB column
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "config.*\\$\\.theme.*AS theme"
      assert sql =~ "metadata.*\\$\\.tags.*AS tags"
    end
  end

  describe "Basic JSON Extraction from Docs" do
    test "extract JSON object field returns JSON" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:json_get, "product.data", "specifications", as: "specs"}  # -> operator
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.data->'specifications' AS specs"
    end

    test "extract JSON value as text" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name", 
            {:json_get_text, "product.data", "brand", as: "brand"}  # ->> operator
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.data->>'brand' AS brand"
    end

    test "extract nested values" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:json_get_path, "product.data", ["specs", "dimensions", "weight"], as: "weight"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.data#>"
      assert sql =~ "AS weight"
      assert ["specs", "dimensions", "weight"] in params or
             "{specs,dimensions,weight}" in params
    end

    test "multiple extraction in one query" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "order.id",
            {:json_get_text, "order.data", "customer_name", as: "customer"},
            {:json_get_text, "order.data", "total", as: "order_total"},
            {:json_get, "order.data", "items", as: "order_items"}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "order\\.data->>'customer_name' AS customer"
      assert sql =~ "order\\.data->>'total' AS order_total"
      assert sql =~ "order\\.data->'items' AS order_items"
    end
  end

  describe "Array Element Access from Docs" do
    test "access array element by index" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:json_get_array_element, "product.tags", 0, as: "primary_tag"},
            {:json_get_array_element_text, "product.tags", 1, as: "secondary_tag"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.tags->0 AS primary_tag"
      assert sql =~ "product\\.tags->>1 AS secondary_tag"
      assert 0 in params
      assert 1 in params
    end

    test "access nested array elements" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "order.id",
            {:json_get_path, "order.data", ["items", "0", "product_id"], as: "first_product"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "order\\.data#>"
      assert sql =~ "AS first_product"
      assert ["items", "0", "product_id"] in params or
             "{items,0,product_id}" in params
    end
  end

  describe "JSONPath Expressions from Docs" do
    test "JSONPath queries" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:jsonb_path_query, "product.data", "$.features[*].name", as: "feature_names"},
            {:jsonb_path_query_first, "product.data", "$.price", as: "price"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "jsonb_path_query.*product\\.data"
      assert sql =~ "AS feature_names"
      assert sql =~ "jsonb_path_query_first.*product\\.data"
      assert sql =~ "AS price"
      assert "$.features[*].name" in params
      assert "$.price" in params
    end

    test "JSONPath with filters" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "order.id",
            {:jsonb_path_query, "order.items", 
              "$[*] ? (@.quantity > 2)", 
              as: "bulk_items"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "jsonb_path_query.*order\\.items"
      assert sql =~ "AS bulk_items"
      assert "$[*] ? (@.quantity > 2)" in params
    end

    test "JSONPath exists check" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:jsonb_path_exists, "product.data", "$.specifications.warranty"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "jsonb_path_exists.*product\\.data"
      assert "$.specifications.warranty" in params
    end
  end

  describe "JSON Testing and Filtering from Docs" do
    test "JSON contains operator" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:jsonb_contains, "product.metadata", %{"category" => "electronics"}}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.metadata @>"
      assert %{"category" => "electronics"} in params
    end

    test "JSON is contained by operator" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:jsonb_contained, "user.preferences", %{"theme" => "dark", "language" => "en"}}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "user\\.preferences <@"
      assert %{"theme" => "dark", "language" => "en"} in params
    end

    test "key exists operator" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:jsonb_has_key, "product.data", "specifications"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.data \\?"
      assert "specifications" in params
    end

    test "any keys exist operator" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:jsonb_has_any_key, "product.tags", ["new", "featured", "sale"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.tags \\?\\|"
      assert ["new", "featured", "sale"] in params
    end

    test "all keys exist operator" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:jsonb_has_all_keys, "product.required_fields", ["name", "price", "sku"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "product\\.required_fields \\?&"
      assert ["name", "price", "sku"] in params
    end
  end
end