defmodule SelectoCone.ConeTest do
  use SelectoTest.DataCase
  
  alias SelectoCone.Core.{Provider, Cone}
  import Ecto.Changeset
  
  describe "Cone initialization" do
    test "creates cone from domain with provider" do
      provider = create_test_provider()
      domain = create_customer_domain()
      
      cone = Cone.init(
        domain,
        SelectoTest.Repo,
        provider,
        validate: false,
        depth_limit: 3,
        validations: [
          {:rentals, :inventory_id, {:validate_with, :inventory}}
        ]
      )
      
      assert cone.domain == domain
      assert cone.provider == provider
      assert cone.repo == SelectoTest.Repo
      assert cone.depth_limit == 3
      assert length(cone.validations) == 1
    end
    
    test "uses default depth limit when not specified" do
      provider = create_test_provider()
      domain = create_customer_domain()
      
      cone = Cone.init(domain, SelectoTest.Repo, provider)
      
      assert cone.depth_limit == 5
    end
    
    test "accepts custom changeset module" do
      provider = create_test_provider()
      domain = create_customer_domain()
      
      cone = Cone.init(
        domain,
        SelectoTest.Repo,
        provider,
        validate: false,
        changeset_module: MyApp.CustomChangeset
      )
      
      assert cone.changeset_module == MyApp.CustomChangeset
    end
    
    test "accepts behavior modules" do
      provider = create_test_provider()
      domain = create_customer_domain()
      
      behaviors = [MyApp.ValidationBehavior, MyApp.TransformBehavior]
      
      cone = Cone.init(
        domain,
        SelectoTest.Repo,
        provider,
        validate: false,
        behaviors: behaviors
      )
      
      assert cone.behaviors == behaviors
    end
  end
  
  describe "Cone changeset generation" do
    test "generates changeset from params" do
      cone = create_test_cone()
      
      params = %{
        "first_name" => "John",
        "last_name" => "Doe",
        "email" => "john@example.com"
      }
      
      changeset = Cone.changeset(cone, params)
      
      assert changeset.valid?
      assert get_change(changeset, :first_name) == "John"
      assert get_change(changeset, :last_name) == "Doe"
      assert get_change(changeset, :email) == "john@example.com"
    end
    
    test "validates required fields" do
      cone = create_test_cone()
      
      # Missing required fields
      params = %{"email" => "test@example.com"}
      
      changeset = Cone.changeset(cone, params)
      
      refute changeset.valid?
      errors = Keyword.keys(changeset.errors)
      assert :first_name in errors
      assert :last_name in errors
    end
    
    test "handles nested associations" do
      cone = create_test_cone_with_rentals()
      
      params = %{
        "first_name" => "Jane",
        "last_name" => "Smith",
        "email" => "jane@example.com",
        "rentals" => [
          %{
            "rental_date" => "2024-01-01T10:00:00Z",
            "inventory_id" => 1
          },
          %{
            "rental_date" => "2024-01-02T14:00:00Z",
            "inventory_id" => 2
          }
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      
      rentals = get_change(changeset, :rentals)
      assert length(rentals) == 2
      
      first_rental = hd(rentals)
      assert get_change(first_rental, :inventory_id) == 1
    end
  end
  
  describe "Cone validation with provider" do
    test "validates fields against provider data" do
      provider = %Provider{
        cached_data: %{
          inventory: [
            %{inventory_id: 1, film_id: 101},
            %{inventory_id: 2, film_id: 102}
          ]
        }
      }
      
      cone = create_test_cone_with_provider(provider)
      
      # Valid inventory IDs
      params = %{
        "first_name" => "John",
        "last_name" => "Doe",
        "email" => "john@example.com",
        "rentals" => [
          %{"rental_date" => "2024-01-01T10:00:00Z", "inventory_id" => 1}
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      assert validated.valid?
    end
    
    test "adds errors for invalid provider selections" do
      provider = %Provider{
        cached_data: %{
          inventory: [
            %{inventory_id: 1, film_id: 101}
          ]
        }
      }
      
      cone = create_test_cone_with_provider(provider)
      
      # Invalid inventory ID (999 not in provider)
      params = %{
        "first_name" => "John",
        "last_name" => "Doe",
        "email" => "john@example.com",
        "rentals" => [
          %{"rental_date" => "2024-01-01T10:00:00Z", "inventory_id" => 999}
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      refute validated.valid?
      errors = Keyword.keys(validated.errors)
      assert :rentals in errors
    end
  end
  
  describe "Cone nested structure building" do
    test "builds nested structure respecting depth limit" do
      cone = create_deep_nested_cone()
      
      nested = Cone.build_nested(cone, 0)
      
      assert is_map(nested)
      # Check that it doesn't nest beyond depth limit
      assert Map.has_key?(nested, :rentals)
    end
    
    test "stops at depth limit" do
      cone = create_test_cone_with_rentals()
      cone = %{cone | depth_limit: 1}
      
      # At depth 0
      nested_0 = Cone.build_nested(cone, 0)
      assert Map.has_key?(nested_0, :rentals)
      
      # At depth limit
      nested_limit = Cone.build_nested(cone, 1)
      assert nested_limit == %{}
    end
  end
  
  describe "Cone updates" do
    test "update_provider replaces the provider" do
      cone = create_test_cone()
      new_provider = create_test_provider()
      
      updated = Cone.update_provider(cone, new_provider)
      
      assert updated.provider == new_provider
    end
    
    test "with_options updates cone configuration" do
      cone = create_test_cone()
      
      new_behaviors = [NewBehavior]
      new_validations = [{:field, :validation}]
      
      updated = Cone.with_options(cone,
        behaviors: new_behaviors,
        validations: new_validations,
        depth_limit: 10
      )
      
      assert updated.behaviors == new_behaviors
      assert updated.validations == new_validations
      assert updated.depth_limit == 10
    end
  end
  
  describe "Complex cone scenarios" do
    test "handles blog domain with nested comments" do
      provider = create_blog_provider()
      domain = create_blog_post_domain()
      
      cone = Cone.init(
        domain,
        SelectoTest.Repo,
        provider,
        validate: false,
        validations: [
          {:author_id, {:validate_with, :authors}},
          {:comments, :author_id, {:validate_with, :authors}}
        ]
      )
      
      params = %{
        "title" => "Test Post",
        "body" => "Post content",
        "author_id" => 1,
        "comments" => [
          %{
            "body" => "Great post!",
            "author_id" => 2
          },
          %{
            "body" => "I agree",
            "author_id" => 3
          }
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      
      assert get_change(changeset, :title) == "Test Post"
      comments = get_change(changeset, :comments)
      assert length(comments) == 2
    end
    
    test "handles solar system hierarchy" do
      provider = create_solar_provider()
      domain = create_solar_system_domain()
      
      cone = Cone.init(
        domain,
        SelectoTest.Repo,
        provider,
        validate: false,
        depth_limit: 3
      )
      
      params = %{
        "name" => "Sol",
        "type" => "G-type",
        "planets" => [
          %{
            "name" => "Earth",
            "distance_from_sun" => 1.0,
            "satellites" => [
              %{"name" => "Moon", "radius" => 1737.1}
            ]
          },
          %{
            "name" => "Mars",
            "distance_from_sun" => 1.5,
            "satellites" => [
              %{"name" => "Phobos", "radius" => 11.1},
              %{"name" => "Deimos", "radius" => 6.2}
            ]
          }
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      
      planets = get_change(changeset, :planets)
      assert length(planets) == 2
      
      earth = hd(planets)
      earth_satellites = get_change(earth, :satellites)
      assert length(earth_satellites) == 1
    end
  end
  
  # Helper functions
  
  defp create_test_provider do
    domain = %{
      source: %{
        source_table: "inventory",
        primary_key: :inventory_id,
        fields: [:inventory_id, :film_id],
        columns: %{
          inventory_id: %{type: :integer},
          film_id: %{type: :integer}
        }
      },
      schemas: %{},
      name: "Inventory"
    }
    
    Provider.init(domain, SelectoTest.Repo, %{}, :public, validate: false)
  end
  
  defp create_test_cone do
    provider = create_test_provider()
    domain = create_customer_domain()
    
    Cone.init(domain, SelectoTest.Repo, provider, validate: false)
  end
  
  defp create_test_cone_with_rentals do
    provider = create_test_provider()
    domain = create_customer_with_rentals_domain()
    
    Cone.init(
      domain,
      SelectoTest.Repo,
      provider,
      validate: false,
      validations: [
        {:rentals, :inventory_id, {:validate_with, :inventory}}
      ]
    )
  end
  
  defp create_test_cone_with_provider(provider) do
    domain = create_customer_with_rentals_domain()
    
    Cone.init(
      domain,
      SelectoTest.Repo,
      provider,
      validate: false,
      validations: [
        {:rentals, :inventory_id, {:validate_with, :inventory}}
      ]
    )
  end
  
  defp create_deep_nested_cone do
    provider = create_test_provider()
    domain = create_deep_nested_domain()
    
    Cone.init(domain, SelectoTest.Repo, provider, validate: false, depth_limit: 3)
  end
  
  defp create_customer_domain do
    %{
      source: %{
        source_table: "customer",
        primary_key: :customer_id,
        fields: [:customer_id, :first_name, :last_name, :email],
        columns: %{
          customer_id: %{type: :integer},
          first_name: %{type: :string, required: true},
          last_name: %{type: :string, required: true},
          email: %{type: :string, required: true}
        }
      },
      schemas: %{},
      name: "Customer"
    }
  end
  
  defp create_customer_with_rentals_domain do
    %{
      source: %{
        source_table: "customer",
        primary_key: :customer_id,
        fields: [:customer_id, :first_name, :last_name, :email],
        columns: %{
          customer_id: %{type: :integer},
          first_name: %{type: :string, required: true},
          last_name: %{type: :string, required: true},
          email: %{type: :string, required: true}
        },
        associations: %{
          rentals: %{
            queryable: "rental",
            cardinality: :many
          }
        }
      },
      schemas: %{
        rentals: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :rental_date, :inventory_id],
          columns: %{
            rental_id: %{type: :integer},
            rental_date: %{type: :utc_datetime, required: true},
            inventory_id: %{type: :integer, required: true}
          }
        }
      }
    }
  end
  
  defp create_deep_nested_domain do
    %{
      source: %{
        source_table: "customer",
        primary_key: :customer_id,
        fields: [:customer_id],
        columns: %{
          customer_id: %{type: :integer}
        },
        associations: %{
          rentals: %{
            queryable: "rental",
            cardinality: :many
          }
        }
      },
      schemas: %{
        rentals: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :rental_date, :inventory_id],
          columns: %{
            rental_id: %{type: :integer},
            rental_date: %{type: :utc_datetime},
            inventory_id: %{type: :integer}
          },
          associations: %{
            inventory: %{
              queryable: "inventory",
              cardinality: :one
            }
          }
        }
      },
      name: "DeepNested"
    }
  end
  
  defp create_blog_provider do
    domain = %{
      source: %{
        source_table: "author",
        primary_key: :id,
        fields: [:id, :name],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string}
        }
      },
      schemas: %{},
      name: "Author"
    }
    
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    
    %{provider | 
      cached_data: %{
        authors: [
          %{id: 1, name: "Author 1"},
          %{id: 2, name: "Author 2"},
          %{id: 3, name: "Author 3"}
        ]
      }
    }
  end
  
  defp create_blog_post_domain do
    %{
      source: %{
        source_table: "post",
        fields: [:id, :title, :body, :author_id],
        columns: %{
          title: %{type: :string, required: true},
          body: %{type: :text, required: true},
          author_id: %{type: :integer, required: true}
        },
        associations: %{
          comments: %{
            queryable: "comment",
            cardinality: :many
          }
        }
      },
      schemas: %{
        comments: %{
          source_table: "comment",
          primary_key: :id,
          fields: [:id, :body, :author_id],
          columns: %{
            id: %{type: :integer},
            body: %{type: :text, required: true},
            author_id: %{type: :integer, required: true}
          }
        }
      }
    }
  end
  
  defp create_solar_provider do
    domain = %{
      source: %{
        source_table: "solar_system",
        primary_key: :id,
        fields: [:id],
        columns: %{id: %{type: :integer}}
      },
      schemas: %{},
      name: "SolarSystem"
    }
    Provider.init(domain, SelectoTest.Repo, %{}, :public, validate: false)
  end
  
  defp create_solar_system_domain do
    %{
      source: %{
        source_table: "solar_system",
        fields: [:id, :name, :type],
        columns: %{
          name: %{type: :string, required: true},
          type: %{type: :string}
        },
        associations: %{
          planets: %{
            queryable: "planet",
            cardinality: :many
          }
        }
      },
      schemas: %{
        planets: %{
          fields: [:id, :name, :distance_from_sun],
          columns: %{
            name: %{type: :string, required: true},
            distance_from_sun: %{type: :float}
          },
          associations: %{
            satellites: %{
              queryable: "satellite",
              cardinality: :many
            }
          }
        },
        satellites: %{
          fields: [:id, :name, :radius],
          columns: %{
            name: %{type: :string, required: true},
            radius: %{type: :float}
          }
        }
      }
    }
  end
end