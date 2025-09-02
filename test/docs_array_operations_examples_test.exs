defmodule DocsArrayOperationsExamplesTest do
  use ExUnit.Case, async: true
  import SelectoTest.TestHelpers

# Tests updated to match actual Selecto API
# Array operations use Selecto.array_select/2, not inline in select/2

  
  # Use test helpers for proper domain configuration

  describe "Array Aggregation Examples from Docs" do
    test "Basic array_agg aggregation" do
      selecto = configure_test_selecto("film")
      
      # Using actual API: array_select for array operations
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:array_agg, "title", as: "film_titles"})
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "title"
      assert sql =~ "AS film_titles"
      assert sql =~ "GROUP BY"
      assert sql =~ "rating"
    end

    test "array_agg with DISTINCT values" do
      selecto = configure_test_selecto("film")
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:array_agg, "rating", distinct: true, as: "unique_ratings"})
        |> Selecto.group_by(["release_year"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "DISTINCT"
      assert sql =~ "rating"
      assert sql =~ "AS unique_ratings"
      assert sql =~ "GROUP BY"
      assert sql =~ "release_year"
    end

    test "array_agg with ORDER BY" do
      selecto = configure_test_selecto("film")
      
      result = 
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select({:array_agg, "title", 
            order_by: [{"release_year", :desc}, {"title", :asc}],
            as: "films_by_year"})
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "ORDER BY"
      assert sql =~ "release_year DESC"
      assert sql =~ "title ASC"
      assert sql =~ "AS films_by_year"
    end

    test "string_agg concatenation" do
      selecto = configure_test_selecto("film")
      
      result = 
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select([
            {:string_agg, "title", delimiter: ", ", as: "film_list"},
            {:string_agg, "description", 
              delimiter: " | ", 
              order_by: [{"actor.last_name", :asc}],
              as: "actor_names"}
          ])
        |> Selecto.group_by(["category.name"])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "STRING_AGG"
      assert sql =~ "film_list"
      assert sql =~ "actor_names"
      assert sql =~ "ORDER BY.*actor.last_name ASC"
      assert ", " in params
      assert " | " in params
    end
  end

  describe "Array Testing and Filtering Examples from Docs" do
    test "array_contains filter" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:array_contains, "film.special_features", ["Trailers", "Deleted Scenes"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "@>"
      assert ["Trailers", "Deleted Scenes"] in params
    end

    test "array_contained filter" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:array_contained, "user.permissions", ["read", "write", "admin"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "<@"
      assert ["read", "write", "admin"] in params
    end

    test "array_overlap filter" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:array_overlap, "product.tags", ["electronics", "computers", "tablets"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "&&"
      assert ["electronics", "computers", "tablets"] in params
    end

    test "array_eq filter" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.filter([
            {:array_eq, "film.special_features", ["Trailers", "Commentaries"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "="
      assert ["Trailers", "Commentaries"] in params
    end
  end

  describe "Array Size Operations Examples from Docs" do
    test "array_length at specific dimension" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:array_length, "product.tags", 1, as: "tag_count"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_LENGTH"
      assert sql =~ "product.tags"
      assert sql =~ "tag_count"
      assert 1 in params
    end

    test "cardinality for total elements" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "matrix.name",
            {:cardinality, "matrix.data", as: "total_elements"}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CARDINALITY"
      assert sql =~ "matrix.data"
      assert sql =~ "total_elements"
    end

    test "array_ndims for number of dimensions" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "dataset.name",
            {:array_ndims, "dataset.values", as: "dimensions"}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_NDIMS"
      assert sql =~ "dataset.values"
      assert sql =~ "dimensions"
    end

    test "array_dims for dimension info" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "matrix.name",
            {:array_dims, "matrix.data", as: "dimension_info"}
          ])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_DIMS"
      assert sql =~ "matrix.data"
      assert sql =~ "dimension_info"
    end
  end

  describe "Array Construction Examples from Docs" do
    test "construct array from values" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "order.id",
            {:array, ["pending", "processing", "shipped"], as: "status_flow"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY"
      assert sql =~ "status_flow"
      assert ["pending", "processing", "shipped"] in params or
             "pending" in params  # Depending on implementation
    end

    test "array_append element" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:array_append, "product.tags", "new-arrival", as: "updated_tags"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_APPEND"
      assert sql =~ "product.tags"
      assert sql =~ "updated_tags"
      assert "new-arrival" in params
    end

    test "array_prepend element" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "notification.id",
            {:array_prepend, "urgent", "notification.types", as: "prioritized_types"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_PREPEND"
      assert sql =~ "notification.types"
      assert sql =~ "prioritized_types"
      assert "urgent" in params
    end

    test "array_cat concatenation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "user.name",
            {:array_cat, "user.roles", ["viewer", "commenter"], as: "all_roles"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_CAT"
      assert sql =~ "user.roles"
      assert sql =~ "all_roles"
      assert ["viewer", "commenter"] in params
    end

    test "array_fill with value" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "grid.name",
            {:array_fill, 0, dimensions: [10, 10], as: "empty_grid"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_FILL"
      assert sql =~ "empty_grid"
      assert 0 in params
      assert [10, 10] in params
    end
  end

  describe "Array Manipulation Examples from Docs" do
    test "array_remove element" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:array_remove, "product.tags", "deprecated", as: "cleaned_tags"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_REMOVE"
      assert sql =~ "product.tags"
      assert sql =~ "cleaned_tags"
      assert "deprecated" in params
    end

    test "array_replace element" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "document.title",
            {:array_replace, "document.tags", "draft", "published", as: "updated_tags"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_REPLACE"
      assert sql =~ "document.tags"
      assert sql =~ "updated_tags"
      assert "draft" in params
      assert "published" in params
    end

    test "array_position find position" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "playlist.name",
            {:array_position, "playlist.songs", "favorite_song_id", as: "position"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_POSITION"
      assert sql =~ "playlist.songs"
      assert sql =~ "position"
      assert "favorite_song_id" in params
    end

    test "array_positions find all positions" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "text.content",
            {:array_positions, "text.keywords", "important", as: "important_positions"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_POSITIONS"
      assert sql =~ "text.keywords"
      assert sql =~ "important_positions"
      assert "important" in params
    end
  end

  describe "Array Transformation Examples from Docs" do
    test "array_to_string conversion" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            {:array_to_string, "product.tags", ", ", as: "tag_list"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_TO_STRING"
      assert sql =~ "product.tags"
      assert sql =~ "tag_list"
      assert ", " in params
    end

    test "string_to_array conversion" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "csv_data.row",
            {:string_to_array, "csv_data.values", ",", as: "parsed_values"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "STRING_TO_ARRAY"
      assert sql =~ "csv_data.values"
      assert sql =~ "parsed_values"
      assert "," in params
    end

    test "array_to_string with null handling" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "report.name",
            {:array_to_string, "report.data", " | ", null_string: "N/A", as: "formatted_data"}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_TO_STRING"
      assert sql =~ "report.data"
      assert sql =~ "formatted_data"
      assert " | " in params
      assert "N/A" in params
    end
  end

  describe "Array Unnesting Examples from Docs" do
    test "basic unnest" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["film.title", "feature"])
        |> Selecto.unnest("film.special_features", as: "feature")
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "UNNEST"
      assert sql =~ "film.special_features"
      assert sql =~ "AS feature"
    end

    test "unnest with ordinality" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["product.name", "tag.value", "tag.position"])
        |> Selecto.unnest("product.tags", as: "tag", with_ordinality: true)
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "UNNEST"
      assert sql =~ "WITH ORDINALITY"
      assert sql =~ "product.tags"
      assert sql =~ "AS tag"
    end

    test "multiple unnests" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["order.id", "item", "quantity"])
        |> Selecto.unnest("order.items", as: "item")
        |> Selecto.unnest("order.quantities", as: "quantity")
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "UNNEST.*order.items.*AS item"
      assert sql =~ "UNNEST.*order.quantities.*AS quantity"
    end
  end

  describe "Advanced Array Patterns from Docs" do
    test "finding products with specific tag combinations" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["product.name", "product.price"])
        |> Selecto.filter([
            # Must have all these tags
            {:array_contains, "product.tags", ["electronics", "wireless"]},
            # Must have at least one of these
            {:array_overlap, "product.tags", ["bluetooth", "wifi", "5g"]},
            # Must not have these tags
            {:not, {:array_overlap, "product.tags", ["discontinued", "recalled"]}}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "@>"
      assert sql =~ "&&"
      assert sql =~ "NOT"
      assert ["electronics", "wireless"] in params
      assert ["bluetooth", "wifi", "5g"] in params
      assert ["discontinued", "recalled"] in params
    end

    test "aggregating arrays of arrays" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select([
            "category.name",
            {:array_agg, {:unnest, "product.tags"}, distinct: true, as: "all_tags"}
          ])
        |> Selecto.group_by(["category.name"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG"
      assert sql =~ "DISTINCT"
      assert sql =~ "UNNEST"
      assert sql =~ "product.tags"
      assert sql =~ "all_tags"
    end

    test "array-based ranking" do
      selecto = configure_test_selecto()
      search_tags = ["laptop", "gaming", "portable"]
      
      result = 
        selecto
        |> Selecto.select([
            "product.name",
            "product.price",
            {:cardinality, 
              {:array_intersect, "product.tags", search_tags}, 
              as: "match_count"}
          ])
        |> Selecto.order_by([{"match_count", :desc}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CARDINALITY"
      assert sql =~ "array_intersect" or sql =~ "ARRAY_INTERSECT"
      assert sql =~ "match_count"
      assert sql =~ "ORDER BY.*match_count DESC"
      assert search_tags in params
    end
  end

  describe "Array Use Cases from Docs" do
    test "tag management system - add tag to products" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.update([
            {:array_append, "tags", "seasonal", as: "tags"}
          ])
        |> Selecto.filter([{"category_id", 5}])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "UPDATE"
      assert sql =~ "ARRAY_APPEND"
      assert sql =~ "tags"
      assert "seasonal" in params
      assert 5 in params
    end

    test "find films with specific feature combinations" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["film.title", "film.rating"])
        |> Selecto.filter([
            {:array_contains, "special_features", ["Commentary"]},
            {:or, [
              {:array_contains, "special_features", ["Deleted Scenes"]},
              {:array_contains, "special_features", ["Behind the Scenes"]}
            ]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "@>"
      assert sql =~ "OR"
      assert ["Commentary"] in params
      assert ["Deleted Scenes"] in params
      assert ["Behind the Scenes"] in params
    end

    test "permission system - check required permissions" do
      selecto = configure_test_selecto()
      required_permissions = ["read", "write", "delete"]
      
      result = 
        selecto
        |> Selecto.select(["user.email", "user.name"])
        |> Selecto.filter([
            {:array_contains, "user.permissions", required_permissions}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "@>"
      assert sql =~ "user.permissions"
      assert required_permissions in params
    end

    test "permission system - find users with admin permissions" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["user.email", {:array_to_string, "permissions", ", ", as: "permission_list"}])
        |> Selecto.filter([
            {:array_overlap, "user.permissions", ["admin", "superadmin", "moderator"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_TO_STRING"
      assert sql =~ "permissions"
      assert sql =~ "permission_list"
      assert sql =~ "&&"
      assert ["admin", "superadmin", "moderator"] in params
    end
  end
end