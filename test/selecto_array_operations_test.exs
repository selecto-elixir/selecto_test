defmodule SelectoArrayOperationsTest do
  use SelectoTest.SelectoCase, async: false
  
  describe "Array Aggregation Operations" do
    test "ARRAY_AGG basic aggregation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.array_select({:array_agg, "title", as: "film_titles"})
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG(title) AS film_titles"
      assert sql =~ "group by"
    end
    
    test "ARRAY_AGG with DISTINCT" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["release_year"])
        |> Selecto.array_select({:array_agg, "rating", 
            distinct: true, 
            as: "unique_ratings"})
        |> Selecto.group_by(["release_year"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG(DISTINCT film.rating) AS unique_ratings"
    end
    
    test "ARRAY_AGG with ORDER BY" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select({:array_agg, "title", 
            order_by: [{"release_year", :desc}, {"title", :asc}],
            as: "films_chronological"})
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG(film.title ORDER BY film.release_year DESC, film.title ASC) AS films_chronological"
    end
    
    test "STRING_AGG operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select({:string_agg, "title", 
            delimiter: ", ",
            order_by: [{"title", :asc}],
            as: "title_list"})
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "STRING_AGG(film.title, $1 ORDER BY film.title ASC) AS title_list"
      assert params == [", "]
    end
  end
  
  describe "Array Filtering Operations" do
    test "ARRAY_CONTAINS filter" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title", "special_features"])
        |> Selecto.array_filter({:array_contains, "special_features", ["Trailers"]})
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "where"
      assert sql =~ "special_features @> $1"
      assert params == [["Trailers"]]
    end
    
    test "ARRAY_OVERLAP filter" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_filter({:array_overlap, "special_features", 
            ["Deleted Scenes", "Behind the Scenes", "Commentary"]})
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "special_features && $1"
      assert params == [["Deleted Scenes", "Behind the Scenes", "Commentary"]]
    end
    
    test "ARRAY_CONTAINED filter" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_filter({:array_contained, "special_features", 
            ["Trailers", "Deleted Scenes", "Behind the Scenes", "Commentary"]})
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "special_features <@ $1"
      assert params == [["Trailers", "Deleted Scenes", "Behind the Scenes", "Commentary"]]
    end
    
    test "Multiple array filters" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_filter([
            {:array_contains, "special_features", ["Trailers"]},
            {:array_overlap, "special_features", ["Commentary", "Behind the Scenes"]}
          ])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "special_features @> $1"
      assert sql =~ "special_features && $2"
      assert params == [["Trailers"], ["Commentary", "Behind the Scenes"]]
    end
  end
  
  describe "Array Size Operations" do
    test "ARRAY_LENGTH operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:array_length, "special_features", 1, as: "feature_count"})
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_LENGTH(film.special_features, 1) AS feature_count"
    end
    
    test "CARDINALITY operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:cardinality, "special_features", as: "total_features"})
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "CARDINALITY(film.special_features) AS total_features"
    end
  end
  
  describe "UNNEST Operations" do
    test "Basic UNNEST operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title", "feature"])
        |> Selecto.unnest("special_features", as: "feature")
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "from film selecto_root, UNNEST(film.special_features) AS feature"
    end
    
    test "UNNEST with ordinality" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title", "feature", "position"])
        |> Selecto.unnest("special_features", as: "feature", with_ordinality: true)
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "UNNEST(film.special_features) WITH ORDINALITY AS feature(value, ordinality)"
    end
  end
  
  describe "Array Manipulation Operations" do
    test "ARRAY_APPEND operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_manipulate({:array_append, "special_features", "Director's Cut", 
            as: "enhanced_features"})
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_APPEND(film.special_features, $1) AS enhanced_features"
      assert params == ["Director's Cut"]
    end
    
    test "ARRAY_REMOVE operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_manipulate({:array_remove, "special_features", "Trailers", 
            as: "features_without_trailers"})
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_REMOVE(film.special_features, $1) AS features_without_trailers"
      assert params == ["Trailers"]
    end
    
    test "ARRAY_TO_STRING operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_manipulate({:array_to_string, "special_features", ", ", 
            as: "features_text"})
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_TO_STRING(film.special_features, $1) AS features_text"
      assert params == [", "]
    end
    
    test "STRING_TO_ARRAY operation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_manipulate({:string_to_array, "description", " ", 
            as: "description_words"})
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "STRING_TO_ARRAY(film.description, $1) AS description_words"
      assert params == [" "]
    end
  end
  
  describe "Complex Array Scenarios" do
    test "Combining array aggregation with filters and manipulation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select([
            {:array_agg, "title", order_by: [{"title", :asc}], as: "film_list"},
            {:array_length, {:array_agg, "film_id"}, 1, as: "film_count"}
          ])
        |> Selecto.array_filter({:array_contains, "special_features", ["Commentary"]})
        |> Selecto.group_by(["rating"])
      
      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "ARRAY_AGG(film.title ORDER BY film.title ASC) AS film_list"
      assert sql =~ "ARRAY_LENGTH(ARRAY_AGG(film.film_id), 1) AS film_count"
      assert sql =~ "special_features @> $1"
      assert sql =~ "group by film.rating"
      assert params == [["Commentary"]]
    end
    
    test "UNNEST with joins and aggregation" do
      selecto = configure_test_selecto()
      
      result = 
        selecto
        |> Selecto.select(["feature", {:count, "*", as: "usage_count"}])
        |> Selecto.unnest("special_features", as: "feature")
        |> Selecto.group_by(["feature"])
        |> Selecto.order_by([{"usage_count", :desc}])
      
      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])
      
      assert sql =~ "select feature, count(*) AS usage_count"
      assert sql =~ "from film selecto_root, UNNEST(film.special_features) AS feature"
      assert sql =~ "group by feature"
      assert sql =~ "order by usage_count DESC"
    end
  end
  
  # Helper function to configure test Selecto instance
  defp configure_test_selecto do
    domain = get_test_domain()
    connection = get_test_connection()
    Selecto.configure(domain, connection, validate: false)
  end
  
  defp get_test_domain do
    %{
      name: "Film",
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description, :release_year, :rating, :special_features],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :text},
          release_year: %{type: :integer},
          rating: %{type: :string},
          special_features: %{type: {:array, :string}}
        },
        associations: %{}
      },
      schemas: %{
        category: %{
          source_table: "category",
          primary_key: :category_id,
          fields: [:category_id, :name],
          redact_fields: [],
          columns: %{
            category_id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        },
        film_category: %{
          source_table: "film_category",
          primary_key: [:film_id, :category_id],
          fields: [:film_id, :category_id],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            category_id: %{type: :integer}
          },
          associations: %{}
        },
        actor: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string}
          },
          associations: %{}
        },
        film_actor: %{
          source_table: "film_actor",
          primary_key: [:actor_id, :film_id],
          fields: [:actor_id, :film_id],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            film_id: %{type: :integer}
          },
          associations: %{}
        },
        customer: %{
          source_table: "customer",
          primary_key: :customer_id,
          fields: [:customer_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            customer_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string}
          },
          associations: %{}
        },
        rental: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :customer_id, :inventory_id],
          redact_fields: [],
          columns: %{
            rental_id: %{type: :integer},
            customer_id: %{type: :integer},
            inventory_id: %{type: :integer}
          },
          associations: %{}
        },
        inventory: %{
          source_table: "inventory",
          primary_key: :inventory_id,
          fields: [:inventory_id, :film_id],
          redact_fields: [],
          columns: %{
            inventory_id: %{type: :integer},
            film_id: %{type: :integer}
          },
          associations: %{}
        }
      },
      joins: %{}
    }
  end
  
  defp get_test_connection do
    # Return mock connection configuration for testing
    [hostname: "localhost", database: "test_db", username: "test", password: "test"]
  end
end