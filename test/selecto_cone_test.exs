defmodule SelectoConeTest do
  use SelectoTest.DataCase
  
  alias SelectoCone.Core.{Provider, Cone, Validator}
  alias SelectoCone.Form.Builder
  
  describe "Provider initialization and configuration" do
    test "creates provider from Selecto domain with base filters" do
      # Create a mock Selecto domain for films
      film_domain = %{
        source: %{
          source_table: "film",
          primary_key: :film_id,
          fields: [:film_id, :title, :description, :rating, :rental_rate],
          columns: %{
            film_id: %{type: :integer},
            title: %{type: :string, required: true},
            description: %{type: :text},
            rating: %{type: :string},
            rental_rate: %{type: :decimal}
          }
        }
      }
      
      provider = Provider.init(
        film_domain,
        SelectoTest.Repo,
        %{rating: "PG"},
        :public
      )
      
      assert provider.selecto == film_domain
      assert provider.context == :public
      assert provider.base_filters == %{rating: "PG"}
      assert provider.context_filters == %{published: true, available: true}
    end
    
    test "admin context has no additional filters" do
      film_domain = %{source: %{source_table: "film"}}
      
      provider = Provider.init(
        film_domain,
        SelectoTest.Repo,
        %{},
        :admin
      )
      
      assert provider.context == :admin
      assert provider.context_filters == %{}
    end
    
    test "can add filters to provider" do
      film_domain = %{source: %{source_table: "film"}}
      
      provider = 
        Provider.init(film_domain, SelectoTest.Repo, %{}, :public)
        |> Provider.add_filters([{:rental_rate, {:lte, 4.99}}])
      
      assert provider.context_filters[:rental_rate] == {:lte, 4.99}
    end
    
    test "can add subselects for data retrieval" do
      film_domain = %{source: %{source_table: "film"}}
      
      provider = 
        Provider.init(film_domain, SelectoTest.Repo, %{}, :public)
        |> Provider.add_subselect(:available_films, fn selecto ->
          # Mock Selecto query builder
          Map.put(selecto, :subselect_available_films, true)
        end)
      
      assert Map.has_key?(provider.subselects, :available_films)
    end
  end
  
  describe "Cone initialization and structure" do
    test "creates cone from Selecto domain with provider" do
      # Provider domain (what's available)
      film_domain = %{
        source: %{
          source_table: "film",
          primary_key: :film_id,
          fields: [:film_id, :title, :rating]
        }
      }
      
      provider = Provider.init(film_domain, SelectoTest.Repo, %{}, :public)
      
      # Cone domain (what we're collecting)
      rental_domain = %{
        source: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :rental_date, :customer_id, :inventory_id],
          columns: %{
            rental_id: %{type: :integer},
            rental_date: %{type: :utc_datetime, required: true},
            customer_id: %{type: :integer, required: true},
            inventory_id: %{type: :integer, required: true}
          },
          associations: %{
            customer: %{
              queryable: SelectoTest.Store.Customer,
              field: :customer,
              owner_key: :customer_id,
              related_key: :customer_id,
              cardinality: :one
            },
            inventory: %{
              queryable: SelectoTest.Store.Inventory,
              field: :inventory,
              owner_key: :inventory_id,
              related_key: :inventory_id,
              cardinality: :one
            }
          }
        }
      }
      
      cone = Cone.init(
        rental_domain,
        SelectoTest.Repo,
        provider,
        depth_limit: 2,
        validations: [
          {:inventory_id, {:validate_with, :available_inventory}}
        ]
      )
      
      assert cone.selecto == rental_domain
      assert cone.provider == provider
      assert cone.depth_limit == 2
      assert length(cone.validations) == 1
    end
    
    test "builds nested structure respecting depth limit" do
      rental_domain = %{
        source: %{
          source_table: "rental",
          associations: %{
            customer: %{cardinality: :one},
            inventory: %{cardinality: :one}
          }
        }
      }
      
      provider = Provider.init(%{}, SelectoTest.Repo, %{}, :public)
      cone = Cone.init(rental_domain, SelectoTest.Repo, provider, depth_limit: 2)
      
      nested = Cone.build_nested(cone, 0)
      
      assert Map.has_key?(nested, :fields)
      assert Map.has_key?(nested, :associations)
    end
  end
  
  describe "Form building from Cone" do
    test "builds form configuration with fields" do
      rental_domain = %{
        source: %{
          source_table: "rental",
          fields: [:rental_id, :rental_date, :customer_id],
          columns: %{
            rental_id: %{type: :integer},
            rental_date: %{type: :utc_datetime, required: true},
            customer_id: %{type: :integer, required: true}
          }
        }
      }
      
      provider = Provider.init(%{}, SelectoTest.Repo, %{}, :public)
      cone = Cone.init(rental_domain, SelectoTest.Repo, provider)
      
      form = Builder.build(cone)
      
      assert form.cone == cone
      assert is_list(form.fields)
      
      # Check field configurations
      field_names = Enum.map(form.fields, & &1.name)
      assert :rental_date in field_names
      assert :customer_id in field_names
      
      # Check field types
      date_field = Enum.find(form.fields, & &1.name == :rental_date)
      assert date_field.type == :datetime
      assert date_field.required == true
    end
    
    test "builds nested forms for associations" do
      customer_domain = %{
        source: %{
          source_table: "customer",
          fields: [:customer_id, :first_name, :last_name],
          associations: %{
            rentals: %{
              queryable: SelectoTest.Store.Rental,
              cardinality: :many,
              min_items: 1,
              max_items: 5
            }
          }
        }
      }
      
      provider = Provider.init(%{}, SelectoTest.Repo, %{}, :public)
      cone = Cone.init(customer_domain, SelectoTest.Repo, provider, depth_limit: 2)
      
      nested_forms = Builder.build_nested_forms(cone)
      
      assert length(nested_forms) == 1
      rental_form = hd(nested_forms)
      
      assert rental_form.name == :rentals
      assert rental_form.cardinality == :many
      assert rental_form.min_items == 1
      assert rental_form.max_items == 5
      assert rental_form.allow_add == true
      assert rental_form.allow_remove == true
    end
  end
  
  describe "Validation with Provider rules" do
    test "validates selections against provider data" do
      # Setup provider with available inventory
      provider = %Provider{
        cached_data: %{
          available_inventory: [
            %{id: 1, film_id: 1},
            %{id: 2, film_id: 2}
          ]
        }
      }
      
      # Valid selection
      assert :ok == Provider.validate_selection(provider, :available_inventory, [1, 2])
      
      # Invalid selection (id 3 not available)
      assert {:error, _message} = Provider.validate_selection(provider, :available_inventory, [1, 3])
    end
    
    test "checks if item is available" do
      provider = %Provider{
        cached_data: %{
          films: [
            %{id: 1, title: "Film 1"},
            %{id: 2, title: "Film 2"}
          ]
        }
      }
      
      assert Provider.is_available?(provider, :films, 1) == true
      assert Provider.is_available?(provider, :films, 3) == false
    end
    
    test "validates changeset with provider rules" do
      provider = %Provider{
        cached_data: %{
          inventory: [%{id: 1}, %{id: 2}]
        }
      }
      
      rental_domain = %{
        source: %{
          source_table: "rental",
          fields: [:inventory_id],
          columns: %{
            inventory_id: %{type: :integer, required: true}
          }
        }
      }
      
      cone = Cone.init(
        rental_domain,
        SelectoTest.Repo,
        provider,
        validations: [{:inventory_id, :inventory}]
      )
      
      # Valid inventory_id
      changeset = %{
        data: %{},
        changes: %{inventory_id: 1},
        errors: [],
        valid?: true
      }
      
      validated = Validator.validate_provider_selection(changeset, :inventory_id, provider, :inventory)
      assert validated.valid? == true
      
      # Invalid inventory_id
      changeset_invalid = %{
        data: %{},
        changes: %{inventory_id: 999},
        errors: [],
        valid?: true
      }
      
      validated_invalid = Validator.validate_provider_selection(changeset_invalid, :inventory_id, provider, :inventory)
      assert validated_invalid.valid? == false
    end
  end
  
  describe "Context-aware behavior" do
    test "public context applies availability filters" do
      domain = %{source: %{source_table: "inventory"}}
      
      public_provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
      admin_provider = Provider.init(domain, SelectoTest.Repo, %{}, :admin)
      
      assert public_provider.context_filters[:available] == true
      assert public_provider.context_filters[:published] == true
      assert admin_provider.context_filters == %{}
    end
    
    test "API context has specific filters" do
      domain = %{source: %{source_table: "inventory"}}
      
      api_provider = Provider.init(domain, SelectoTest.Repo, %{}, :api)
      
      assert api_provider.context_filters[:api_accessible] == true
    end
  end
  
  describe "Complex nested rental scenario" do
    setup do
      # Setup a complex rental scenario with Customer -> Rentals -> Inventory -> Film
      
      # Provider: Available inventory
      inventory_provider_domain = %{
        source: %{
          source_table: "inventory",
          fields: [:inventory_id, :film_id, :store_id]
        }
      }
      
      provider = Provider.init(
        inventory_provider_domain,
        SelectoTest.Repo,
        %{store_id: 1},
        :public
      )
      |> Provider.set_data_query(fn selecto ->
        # Mock adding subselects
        Map.put(selecto, :mock_subselects, true)
      end)
      
      # Cone: Customer creating rentals
      customer_rental_domain = %{
        source: %{
          source_table: "customer",
          primary_key: :customer_id,
          schema: SelectoTest.Store.Customer,
          fields: [:customer_id, :first_name, :last_name, :email],
          columns: %{
            customer_id: %{type: :integer},
            first_name: %{type: :string, required: true},
            last_name: %{type: :string, required: true},
            email: %{type: :string, required: true}
          },
          associations: %{
            rentals: %{
              queryable: SelectoTest.Store.Rental,
              cardinality: :many,
              source_table: "rental",
              fields: [:rental_id, :rental_date, :inventory_id],
              columns: %{
                rental_date: %{type: :utc_datetime, required: true},
                inventory_id: %{type: :integer, required: true}
              }
            }
          }
        }
      }
      
      cone = Cone.init(
        customer_rental_domain,
        SelectoTest.Repo,
        provider,
        depth_limit: 2,
        validations: [
          {:rentals, :inventory_id, {:validate_with, :available_inventory}}
        ]
      )
      
      {:ok, cone: cone, provider: provider}
    end
    
    test "builds complete form structure for customer rentals", %{cone: cone} do
      form = Builder.build(cone, %{
        "first_name" => "John",
        "last_name" => "Doe",
        "email" => "john@example.com",
        "rentals" => [
          %{"rental_date" => "2024-01-01T10:00:00Z", "inventory_id" => 1}
        ]
      })
      
      assert form.cone == cone
      
      # Check main fields
      field_names = Enum.map(form.fields, & &1.name)
      assert :first_name in field_names
      assert :last_name in field_names
      assert :email in field_names
      
      # Check nested forms
      nested = form.nested_forms
      assert length(nested) > 0
      
      rental_form = Enum.find(nested, & &1.name == :rentals)
      assert rental_form.cardinality == :many
      assert rental_form.allow_add == true
    end
    
    test "validates rental inventory against provider", %{cone: cone} do
      # Update provider with available inventory
      provider_with_data = %{cone.provider | 
        cached_data: %{
          available_inventory: [
            %{id: 1, film_id: 101},
            %{id: 2, film_id: 102}
          ]
        }
      }
      
      cone_with_provider = %{cone | provider: provider_with_data}
      
      # Create changeset with valid inventory
      changeset = Cone.changeset(cone_with_provider, %{
        "first_name" => "John",
        "last_name" => "Doe",
        "email" => "john@example.com",
        "rentals" => [
          %{"rental_date" => "2024-01-01T10:00:00Z", "inventory_id" => 1}
        ]
      })
      
      # Validate with provider
      validated = Cone.validate_with_provider(cone_with_provider, changeset)
      
      # The changeset should remain valid for valid inventory
      assert is_map(validated)
    end
  end
  
  describe "Form field type inference" do
    test "infers correct field types from column definitions" do
      domain = %{
        source: %{
          source_table: "test",
          fields: [:text_field, :number_field, :bool_field, :date_field],
          columns: %{
            text_field: %{type: :string},
            number_field: %{type: :integer},
            bool_field: %{type: :boolean},
            date_field: %{type: :utc_datetime}
          }
        }
      }
      
      provider = Provider.init(%{}, SelectoTest.Repo, %{}, :public)
      cone = Cone.init(domain, SelectoTest.Repo, provider)
      
      form = Builder.build(cone)
      
      text_field = Enum.find(form.fields, & &1.name == :text_field)
      assert text_field.type == :text
      
      number_field = Enum.find(form.fields, & &1.name == :number_field)
      assert number_field.type == :number
      
      bool_field = Enum.find(form.fields, & &1.name == :bool_field)
      assert bool_field.type == :checkbox
      
      date_field = Enum.find(form.fields, & &1.name == :date_field)
      assert date_field.type == :datetime
    end
  end
end