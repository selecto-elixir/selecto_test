defmodule SelectoCone.FormTest do
  use SelectoTest.DataCase
  
  alias SelectoCone.Core.{Provider, Cone}
  alias SelectoCone.Form.Builder
  
  describe "Form field building" do
    test "builds fields from cone domain" do
      cone = create_test_cone()
      
      fields = Builder.build_fields(cone)
      
      assert is_list(fields)
      assert length(fields) > 0
      
      # Check field structure
      first_field = hd(fields)
      assert Map.has_key?(first_field, :name)
      assert Map.has_key?(first_field, :type)
      assert Map.has_key?(first_field, :label)
      assert Map.has_key?(first_field, :required)
    end
    
    test "correctly identifies required fields" do
      cone = create_cone_with_required_fields()
      
      fields = Builder.build_fields(cone)
      
      # Find required fields
      first_name = Enum.find(fields, & &1.name == :first_name)
      email = Enum.find(fields, & &1.name == :email)
      middle_name = Enum.find(fields, & &1.name == :middle_name)
      
      assert first_name.required == true
      assert email.required == true
      assert middle_name.required == false
    end
    
    test "infers correct field types" do
      cone = create_cone_with_various_types()
      
      fields = Builder.build_fields(cone)
      
      # Check type inference
      text_field = Enum.find(fields, & &1.name == :name)
      number_field = Enum.find(fields, & &1.name == :age)
      bool_field = Enum.find(fields, & &1.name == :active)
      date_field = Enum.find(fields, & &1.name == :created_at)
      
      assert text_field.type == :text
      assert number_field.type == :number
      assert bool_field.type == :checkbox
      assert date_field.type == :datetime
    end
    
    test "humanizes field labels" do
      cone = create_test_cone()
      
      fields = Builder.build_fields(cone)
      
      first_name = Enum.find(fields, & &1.name == :first_name)
      assert first_name.label == "First Name"
      
      customer_id = Enum.find(fields, & &1.name == :customer_id)
      assert customer_id.label == "Customer Id"
    end
  end
  
  describe "Form building with nested associations" do
    test "builds nested forms for associations" do
      cone = create_cone_with_associations()
      
      nested_forms = Builder.build_nested_forms(cone)
      
      assert is_list(nested_forms)
      assert length(nested_forms) > 0
      
      rentals_form = Enum.find(nested_forms, & &1.name == :rentals)
      assert rentals_form != nil
      assert rentals_form.cardinality == :many
      assert rentals_form.allow_add == true
      assert rentals_form.allow_remove == true
    end
    
    test "respects depth limit when building nested forms" do
      cone = create_cone_with_associations()
      cone = %{cone | depth_limit: 2}
      
      # At depth 0
      nested_0 = Builder.build_nested_forms(cone, 0)
      assert length(nested_0) > 0
      
      # At depth 1
      nested_1 = Builder.build_nested_forms(cone, 1)
      assert length(nested_1) > 0
      
      # At depth limit
      nested_limit = Builder.build_nested_forms(cone, 2)
      assert nested_limit == []
    end
    
    test "includes min/max items for associations" do
      cone = create_cone_with_constrained_associations()
      
      nested_forms = Builder.build_nested_forms(cone)
      
      rentals_form = Enum.find(nested_forms, & &1.name == :rentals)
      assert rentals_form.min_items == 1
      assert rentals_form.max_items == 10
    end
  end
  
  describe "Form field configuration" do
    test "builds field config with validations" do
      cone = create_cone_with_validations()
      
      field_config = Builder.build_field_config(cone, :inventory_id)
      
      assert field_config.name == :inventory_id
      assert is_list(field_config.validations)
    end
    
    test "gets field validations from cone" do
      cone = create_cone_with_validations()
      
      validations = Builder.get_field_validations(cone, :inventory_id)
      
      assert is_list(validations)
      assert length(validations) > 0
    end
    
    test "includes provider options for select fields" do
      provider = create_provider_with_options()
      cone = create_cone_with_provider(provider)
      
      field_config = Builder.build_field_config(cone, :package_id)
      
      assert is_list(field_config.options)
      assert length(field_config.options) > 0
    end
  end
  
  describe "Complete form building" do
    test "builds complete form structure" do
      provider = create_provider_with_data()
      cone = create_complete_cone(provider)
      
      params = %{
        "first_name" => "John",
        "last_name" => "Doe",
        "email" => "john@example.com"
      }
      
      form = Builder.build(cone, params)
      
      assert form.cone == cone
      assert is_map(form.changeset)
      assert is_list(form.fields)
      assert is_list(form.nested_forms)
      assert is_map(form.available_data)
    end
    
    test "includes available data from provider" do
      provider = create_provider_with_data()
      cone = create_complete_cone(provider)
      
      form = Builder.build(cone)
      
      available = form.available_data
      assert Map.has_key?(available, :films)
      assert Map.has_key?(available, :customers)
    end
  end
  
  describe "Field type inference edge cases" do
    test "handles text vs textarea distinction" do
      domain = %{
        source: %{
          source_table: "test",
          fields: [:short_text, :long_text],
          columns: %{
            short_text: %{type: :string},
            long_text: %{type: :text}
          }
        }
      }
      
      provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
      cone = Cone.init(domain, SelectoTest.Repo, provider)
      
      fields = Builder.build_fields(cone)
      
      short = Enum.find(fields, & &1.name == :short_text)
      long = Enum.find(fields, & &1.name == :long_text)
      
      assert short.type == :text
      assert long.type == :textarea
    end
    
    test "handles various datetime types" do
      domain = %{
        source: %{
          source_table: "test",
          fields: [:date_field, :time_field, :datetime_field],
          columns: %{
            date_field: %{type: :date},
            time_field: %{type: :time},
            datetime_field: %{type: :utc_datetime}
          }
        }
      }
      
      provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
      cone = Cone.init(domain, SelectoTest.Repo, provider)
      
      fields = Builder.build_fields(cone)
      
      date = Enum.find(fields, & &1.name == :date_field)
      time = Enum.find(fields, & &1.name == :time_field)
      datetime = Enum.find(fields, & &1.name == :datetime_field)
      
      assert date.type == :date
      assert time.type == :time
      assert datetime.type == :datetime
    end
    
    test "handles numeric types" do
      domain = %{
        source: %{
          source_table: "test",
          fields: [:int_field, :float_field, :decimal_field],
          columns: %{
            int_field: %{type: :integer},
            float_field: %{type: :float},
            decimal_field: %{type: :decimal}
          }
        }
      }
      
      provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
      cone = Cone.init(domain, SelectoTest.Repo, provider)
      
      fields = Builder.build_fields(cone)
      
      int = Enum.find(fields, & &1.name == :int_field)
      float = Enum.find(fields, & &1.name == :float_field)
      decimal = Enum.find(fields, & &1.name == :decimal_field)
      
      assert int.type == :number
      assert float.type == :number
      assert decimal.type == :number
    end
  end
  
  # Helper functions
  
  defp create_test_cone do
    domain = %{
      source: %{
        source_table: "customer",
        fields: [:customer_id, :first_name, :last_name, :email],
        columns: %{
          customer_id: %{type: :integer},
          first_name: %{type: :string},
          last_name: %{type: :string},
          email: %{type: :string}
        }
      }
    }
    
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    Cone.init(domain, SelectoTest.Repo, provider)
  end
  
  defp create_cone_with_required_fields do
    domain = %{
      source: %{
        source_table: "customer",
        fields: [:first_name, :middle_name, :last_name, :email],
        columns: %{
          first_name: %{type: :string, required: true},
          middle_name: %{type: :string, required: false},
          last_name: %{type: :string},
          email: %{type: :string, required: true}
        }
      },
      schemas: %{}
    }
    
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    Cone.init(domain, SelectoTest.Repo, provider)
  end
  
  defp create_cone_with_various_types do
    domain = %{
      source: %{
        source_table: "test",
        fields: [:name, :age, :active, :created_at],
        columns: %{
          name: %{type: :string},
          age: %{type: :integer},
          active: %{type: :boolean},
          created_at: %{type: :utc_datetime}
        }
      },
      schemas: %{}
    }
    
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    Cone.init(domain, SelectoTest.Repo, provider)
  end
  
  defp create_cone_with_associations do
    domain = %{
      source: %{
        source_table: "customer",
        fields: [:customer_id, :first_name],
        columns: %{
          customer_id: %{type: :integer},
          first_name: %{type: :string}
        },
        associations: %{
          rentals: %{
            queryable: :rental,
            cardinality: :many
          },
          address: %{
            queryable: :address,
            cardinality: :one
          }
        }
      },
      schemas: %{
        rental: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :customer_id],
          columns: %{
            rental_id: %{type: :integer},
            customer_id: %{type: :integer}
          }
        },
        address: %{
          source_table: "address",
          primary_key: :address_id,
          fields: [:address_id, :address],
          columns: %{
            address_id: %{type: :integer},
            address: %{type: :string}
          }
        }
      }
    }
    
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    Cone.init(domain, SelectoTest.Repo, provider)
  end
  
  defp create_cone_with_constrained_associations do
    domain = %{
      source: %{
        source_table: "inventory",
        fields: [:inventory_id],
        columns: %{
          inventory_id: %{type: :integer}
        },
        associations: %{
          rentals: %{
            queryable: :rental,
            cardinality: :many,
            min_items: 1,
            max_items: 10
          }
        }
      },
      schemas: %{
        rental: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :inventory_id],
          columns: %{
            rental_id: %{type: :integer},
            inventory_id: %{type: :integer}
          }
        }
      }
    }
    
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    Cone.init(domain, SelectoTest.Repo, provider)
  end
  
  defp create_cone_with_validations do
    domain = %{
      source: %{
        source_table: "rental",
        fields: [:rental_id, :inventory_id],
        columns: %{
          rental_id: %{type: :integer},
          inventory_id: %{type: :integer, required: true}
        }
      },
      schemas: %{}
    }
    
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    Cone.init(
      domain,
      SelectoTest.Repo,
      provider,
      validations: [
        {:inventory_id, {:validate_with, :inventory}}
      ]
    )
  end
  
  defp create_provider_with_options do
    domain = %{source: %{source_table: "test"}, schemas: %{}}
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    
    %{provider |
      cached_data: %{
        packages: [
          %{package_id: 1, name: "Basic"},
          %{package_id: 2, name: "Premium"},
          %{package_id: 3, name: "Enterprise"}
        ]
      }
    }
  end
  
  defp create_cone_with_provider(provider) do
    domain = %{
      source: %{
        source_table: "inventory",
        fields: [:inventory_id, :film_id],
        columns: %{
          inventory_id: %{type: :integer},
          film_id: %{type: :integer}
        }
      },
      schemas: %{}
    }
    
    Cone.init(domain, SelectoTest.Repo, provider)
  end
  
  defp create_provider_with_data do
    domain = %{source: %{source_table: "test"}, schemas: %{}}
    provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
    
    %{provider |
      cached_data: %{
        films: [
          %{film_id: 1, title: "Film 1"},
          %{film_id: 2, title: "Film 2"}
        ],
        customers: [
          %{customer_id: 1, first_name: "John"},
          %{customer_id: 2, first_name: "Jane"}
        ]
      }
    }
  end
  
  defp create_complete_cone(provider) do
    domain = %{
      source: %{
        source_table: "customer",
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
            cardinality: :many
          }
        }
      }
    }
    
    Cone.init(domain, SelectoTest.Repo, provider)
  end
end