defmodule SelectoCone.BasicTest do
  @moduledoc """
  Basic tests for SelectoCone functionality.
  These tests verify the core modules work without complex Selecto domain validation.
  """
  use ExUnit.Case
  
  alias SelectoCone.Core.{Provider, Cone}
  alias SelectoCone.Form.Builder
  
  describe "SelectoCone module availability" do
    test "Provider module is available" do
      assert Code.ensure_loaded?(SelectoCone.Core.Provider)
    end
    
    test "Cone module is available" do
      assert Code.ensure_loaded?(SelectoCone.Core.Cone)
    end
    
    test "Form Builder module is available" do
      assert Code.ensure_loaded?(SelectoCone.Form.Builder)
    end
    
    test "Validator module is available" do
      assert Code.ensure_loaded?(SelectoCone.Core.Validator)
    end
  end
  
  describe "Provider basic functionality" do
    test "Provider struct has expected fields" do
      provider = %Provider{}
      
      assert Map.has_key?(provider, :selecto)
      assert Map.has_key?(provider, :domain)
      assert Map.has_key?(provider, :repo)
      assert Map.has_key?(provider, :context)
      assert Map.has_key?(provider, :base_filters)
      assert Map.has_key?(provider, :context_filters)
      assert Map.has_key?(provider, :cached_data)
    end
    
    test "Provider context filters work correctly" do
      # Test without actual Selecto initialization
      provider = %Provider{
        context: :public,
        context_filters: [{:published, {:eq, true}}, {:available, {:eq, true}}],
        cached_data: %{}
      }
      
      assert provider.context == :public
      assert length(provider.context_filters) == 2
    end
    
    test "Provider cached data management" do
      provider = %Provider{
        cached_data: %{
          items: [
            %{id: 1, name: "Item 1"},
            %{id: 2, name: "Item 2"}
          ]
        }
      }
      
      items = Provider.get_available_options(provider, :items)
      assert length(items) == 2
      assert hd(items).name == "Item 1"
    end
    
    test "Provider validate_selection with mock data" do
      provider = %Provider{
        cached_data: %{
          inventory: [
            %{id: 1, name: "Item 1"},
            %{id: 2, name: "Item 2"}
          ]
        }
      }
      
      # Valid selection
      assert Provider.validate_selection(provider, :inventory, [1, 2]) == :ok
      
      # Invalid selection
      assert {:error, message} = Provider.validate_selection(provider, :inventory, [3])
      assert message =~ "invalid"
    end
  end
  
  describe "Cone basic functionality" do
    test "Cone struct has expected fields" do
      cone = %Cone{}
      
      assert Map.has_key?(cone, :selecto)
      assert Map.has_key?(cone, :provider)
      assert Map.has_key?(cone, :domain)
      assert Map.has_key?(cone, :repo)
      assert Map.has_key?(cone, :changeset_module)
      assert Map.has_key?(cone, :behaviors)
      assert Map.has_key?(cone, :validations)
      assert Map.has_key?(cone, :depth_limit)
    end
    
    test "Cone depth limit defaults" do
      cone = %Cone{depth_limit: 5}
      assert cone.depth_limit == 5
    end
    
    test "Cone can store validations" do
      validations = [
        {:field1, {:validate_with, :type1}},
        {:field2, {:validate_with, :type2}}
      ]
      
      cone = %Cone{validations: validations}
      assert length(cone.validations) == 2
    end
  end
  
  describe "Form Builder basic functionality" do
    test "builds field configuration" do
      # Create a minimal cone with mock data
      cone = %Cone{
        domain: %{
          source: %{
            fields: [:name, :email],
            columns: %{
              name: %{type: :string, required: true},
              email: %{type: :string, required: true}
            }
          }
        }
      }
      
      fields = Builder.build_fields(cone)
      
      assert is_list(fields)
      assert length(fields) == 2
      
      name_field = Enum.find(fields, & &1.name == :name)
      assert name_field.type == :text
      assert name_field.required == true
      assert name_field.label == "Name"
      
      email_field = Enum.find(fields, & &1.name == :email)
      assert email_field.type == :text
      assert email_field.required == true
      assert email_field.label == "Email"
    end
    
    test "infers field types correctly" do
      cone = %Cone{
        domain: %{
          source: %{
            fields: [:active, :age, :created_at],
            columns: %{
              active: %{type: :boolean},
              age: %{type: :integer},
              created_at: %{type: :utc_datetime}
            }
          }
        }
      }
      
      fields = Builder.build_fields(cone)
      
      active_field = Enum.find(fields, & &1.name == :active)
      assert active_field.type == :checkbox
      
      age_field = Enum.find(fields, & &1.name == :age)
      assert age_field.type == :number
      
      created_field = Enum.find(fields, & &1.name == :created_at)
      assert created_field.type == :datetime
    end
  end
  
  describe "Integration between Provider and Cone" do
    test "Cone can reference a Provider" do
      provider = %Provider{
        context: :public,
        cached_data: %{
          items: [%{id: 1}, %{id: 2}]
        }
      }
      
      cone = %Cone{
        provider: provider,
        validations: [{:item_id, {:validate_with, :items}}]
      }
      
      assert cone.provider == provider
      assert cone.provider.context == :public
    end
    
    test "update_provider updates the cone's provider" do
      old_provider = %Provider{context: :public}
      new_provider = %Provider{context: :admin}
      
      cone = %Cone{provider: old_provider}
      updated = Cone.update_provider(cone, new_provider)
      
      assert updated.provider.context == :admin
    end
    
    test "with_options updates cone configuration" do
      cone = %Cone{
        behaviors: [],
        validations: [],
        depth_limit: 3
      }
      
      updated = Cone.with_options(cone,
        behaviors: [TestBehavior],
        validations: [{:field, :validation}],
        depth_limit: 10
      )
      
      assert updated.behaviors == [TestBehavior]
      assert length(updated.validations) == 1
      assert updated.depth_limit == 10
    end
  end
  
  describe "Context functionality" do
    test "different contexts have different filters" do
      public_filters = [{:published, {:eq, true}}, {:available, {:eq, true}}]
      admin_filters = []
      api_filters = [{:api_accessible, {:eq, true}}]
      
      public_provider = %Provider{context: :public, context_filters: public_filters}
      admin_provider = %Provider{context: :admin, context_filters: admin_filters}
      api_provider = %Provider{context: :api, context_filters: api_filters}
      
      assert public_provider.context_filters == public_filters
      assert admin_provider.context_filters == []
      assert api_provider.context_filters == api_filters
    end
  end
  
  describe "Nested data concepts" do
    test "cone can represent nested associations" do
      cone = %Cone{
        domain: %{
          source: %{
            associations: %{
              items: %{cardinality: :many},
              address: %{cardinality: :one}
            }
          }
        }
      }
      
      associations = cone.domain.source.associations
      assert associations.items.cardinality == :many
      assert associations.address.cardinality == :one
    end
    
    test "form builder handles nested forms concept" do
      cone = %Cone{
        domain: %{
          source: %{
            associations: %{
              rentals: %{
                cardinality: :many,
                min_items: 1,
                max_items: 5
              }
            }
          }
        },
        depth_limit: 2
      }
      
      nested_forms = Builder.build_nested_forms(cone, 0)
      
      assert is_list(nested_forms)
      rental_form = Enum.find(nested_forms, & &1.name == :rentals)
      
      assert rental_form.cardinality == :many
      assert rental_form.min_items == 1
      assert rental_form.max_items == 5
      assert rental_form.allow_add == true
      assert rental_form.allow_remove == true
    end
  end
  
  describe "Validation concepts" do
    test "provider can validate selections" do
      provider = %Provider{
        cached_data: %{
          packages: [
            %{package_id: 1, name: "Basic"},
            %{package_id: 2, name: "Premium"}
          ]
        }
      }
      
      # Valid package selection
      assert Provider.validate_selection(provider, :packages, [1]) == :ok
      
      # Invalid package selection
      result = Provider.validate_selection(provider, :packages, [999])
      assert {:error, _message} = result
    end
    
    test "cone stores validation rules" do
      cone = %Cone{
        validations: [
          {:inventory_id, {:validate_with, :inventory}},
          {:package_id, {:validate_with, :packages}},
          {:registrants, :item_id, {:validate_with, :items}}
        ]
      }
      
      assert length(cone.validations) == 3
      
      # Check nested validation
      nested_validation = Enum.find(cone.validations, fn
        {:registrants, _, _} -> true
        _ -> false
      end)
      
      assert {:registrants, :item_id, {:validate_with, :items}} = nested_validation
    end
  end
end