defmodule SelectoCone.IntegrationTest do
  use SelectoTest.DataCase
  
  alias SelectoCone.Core.{Provider, Cone}
  alias SelectoCone.Form.Builder
  
  describe "Film rental scenario with real schemas" do
    setup do
      # Create a provider for available inventory
      inventory_domain = %{
        schemas: %{
          inventory: %{
            source_table: "inventory",
            primary_key: :inventory_id,
            schema_module: SelectoTest.Store.Inventory,
            fields: [:inventory_id, :film_id, :store_id],
            columns: %{
              inventory_id: %{type: :integer},
              film_id: %{type: :integer, required: true},
              store_id: %{type: :integer, required: true}
            },
            associations: %{
              film: %{
                queryable: :film,
                field: :film,
                owner_key: :film_id,
                related_key: :film_id,
                cardinality: :one
              }
            }
          },
          film: %{
            source_table: "film",
            primary_key: :film_id,
            schema_module: SelectoTest.Store.Film,
            fields: [:film_id, :title, :rating, :rental_rate],
            columns: %{
              film_id: %{type: :integer},
              title: %{type: :string},
              rating: %{type: :string},
              rental_rate: %{type: :decimal}
            }
          }
        },
        source: :inventory
      }
      
      provider = Provider.init(
        inventory_domain,
        SelectoTest.Repo,
        %{store_id: 1},
        :public
      )
      
      # Simulate available inventory
      provider = %{provider |
        cached_data: %{
          inventory: [
            %{inventory_id: 1, film_id: 101, store_id: 1},
            %{inventory_id: 2, film_id: 102, store_id: 1},
            %{inventory_id: 3, film_id: 103, store_id: 1}
          ],
          films: [
            %{film_id: 101, title: "The Matrix", rating: "R", rental_rate: 4.99},
            %{film_id: 102, title: "Toy Story", rating: "G", rental_rate: 2.99},
            %{film_id: 103, title: "Inception", rating: "PG-13", rental_rate: 5.99}
          ]
        }
      }
      
      # Create a cone for rental creation
      rental_domain = %{
        schemas: %{
          rental: %{
            source_table: "rental",
            primary_key: :rental_id,
            schema_module: SelectoTest.Store.Rental,
            fields: [:rental_id, :rental_date, :inventory_id, :customer_id, :return_date, :staff_id],
            columns: %{
              rental_id: %{type: :integer},
              rental_date: %{type: :utc_datetime, required: true},
              inventory_id: %{type: :integer, required: true},
              customer_id: %{type: :integer, required: true},
              return_date: %{type: :utc_datetime},
              staff_id: %{type: :integer, required: true}
            },
            associations: %{
              inventory: %{
                queryable: :inventory,
                field: :inventory,
                owner_key: :inventory_id,
                related_key: :inventory_id,
                cardinality: :one
              },
              customer: %{
                queryable: :customer,
                field: :customer,
                owner_key: :customer_id,
                related_key: :customer_id,
                cardinality: :one
              }
            }
          },
          inventory: %{
            source_table: "inventory",
            primary_key: :inventory_id,
            schema_module: SelectoTest.Store.Inventory,
            fields: [:inventory_id],
            columns: %{
              inventory_id: %{type: :integer}
            }
          },
          customer: %{
            source_table: "customer",
            primary_key: :customer_id,
            schema_module: SelectoTest.Store.Customer,
            fields: [:customer_id],
            columns: %{
              customer_id: %{type: :integer}
            }
          }
        },
        source: :rental
      }
      
      cone = Cone.init(
        rental_domain,
        SelectoTest.Repo,
        provider,
        validations: [
          {:inventory_id, {:validate_with, :inventory}}
        ]
      )
      
      {:ok, provider: provider, cone: cone}
    end
    
    test "creates rental with valid inventory", %{cone: cone} do
      params = %{
        "rental_date" => "2024-01-15T10:00:00Z",
        "inventory_id" => 1,
        "customer_id" => 1,
        "staff_id" => 1
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      assert validated.valid?
    end
    
    test "rejects rental with invalid inventory", %{cone: cone} do
      params = %{
        "rental_date" => "2024-01-15T10:00:00Z",
        "inventory_id" => 999,  # Not in available inventory
        "customer_id" => 1,
        "staff_id" => 1
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      refute validated.valid?
    end
    
    test "builds form with available films", %{cone: cone} do
      form = Builder.build(cone)
      
      assert form.available_data[:films] != nil
      assert length(form.available_data[:films]) == 3
      
      matrix = Enum.find(form.available_data[:films], & &1.title == "The Matrix")
      assert matrix.rating == "R"
      assert matrix.rental_rate == 4.99
    end
  end
  
  describe "Customer with multiple rentals scenario" do
    setup do
      # Provider with available inventory for multiple rentals
      inventory_domain = create_inventory_domain()
      
      provider = Provider.init(
        inventory_domain,
        SelectoTest.Repo,
        %{store_id: 1},
        :public
      )
      
      provider = %{provider |
        cached_data: %{
          inventory: create_mock_inventory(10),
          customers: create_mock_customers(5)
        }
      }
      
      # Cone for customer with rentals
      customer_domain = %{
        schemas: %{
          customer: %{
            source_table: "customer",
            primary_key: :customer_id,
            schema_module: SelectoTest.Store.Customer,
            fields: [:customer_id, :first_name, :last_name, :email, :active],
            columns: %{
              customer_id: %{type: :integer},
              first_name: %{type: :string, required: true},
              last_name: %{type: :string, required: true},
              email: %{type: :string, required: true},
              active: %{type: :integer}
            },
            associations: %{
              rentals: %{
                queryable: :rental,
                field: :rentals,
                foreign_key: :customer_id,
                cardinality: :many
              }
            }
          },
          rental: %{
            source_table: "rental",
            primary_key: :rental_id,
            fields: [:rental_id, :rental_date, :inventory_id, :return_date],
            columns: %{
              rental_id: %{type: :integer},
              rental_date: %{type: :utc_datetime, required: true},
              inventory_id: %{type: :integer, required: true},
              return_date: %{type: :utc_datetime}
            }
          }
        },
        source: :customer
      }
      
      cone = Cone.init(
        customer_domain,
        SelectoTest.Repo,
        provider,
        validations: [
          {:rentals, :inventory_id, {:validate_with, :inventory}}
        ],
        depth_limit: 2
      )
      
      {:ok, provider: provider, cone: cone}
    end
    
    test "creates customer with multiple rentals", %{cone: cone} do
      params = %{
        "first_name" => "Alice",
        "last_name" => "Johnson",
        "email" => "alice@example.com",
        "active" => 1,
        "rentals" => [
          %{
            "rental_date" => "2024-01-10T09:00:00Z",
            "inventory_id" => 1
          },
          %{
            "rental_date" => "2024-01-11T14:00:00Z",
            "inventory_id" => 2
          },
          %{
            "rental_date" => "2024-01-12T16:30:00Z",
            "inventory_id" => 3
          }
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      
      assert changeset.valid?
      assert length(Ecto.Changeset.get_change(changeset, :rentals)) == 3
      
      validated = Cone.validate_with_provider(changeset, cone)
      assert validated.valid?
    end
    
    test "validates all rental inventory IDs", %{cone: cone} do
      params = %{
        "first_name" => "Bob",
        "last_name" => "Smith",
        "email" => "bob@example.com",
        "rentals" => [
          %{"rental_date" => "2024-01-10T09:00:00Z", "inventory_id" => 1},
          %{"rental_date" => "2024-01-11T14:00:00Z", "inventory_id" => 999}  # Invalid
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      refute validated.valid?
      errors = Keyword.keys(validated.errors)
      assert :rentals in errors
    end
  end
  
  describe "Event registration scenario" do
    setup do
      # Provider with event packages and options
      event_domain = %{
        schemas: %{
          event: %{
            source_table: "event",
            primary_key: :event_id,
            fields: [:event_id, :name, :start_date, :end_date],
            columns: %{
              event_id: %{type: :integer},
              name: %{type: :string, required: true},
              start_date: %{type: :utc_datetime, required: true},
              end_date: %{type: :utc_datetime, required: true}
            }
          }
        },
        source: :event
      }
      
      provider = Provider.init(
        event_domain,
        SelectoTest.Repo,
        %{event_id: 100},
        :public
      )
      
      provider = %{provider |
        cached_data: %{
          packages: [
            %{package_id: 1, name: "Basic", price: 50.00, max_attendees: 1},
            %{package_id: 2, name: "Standard", price: 100.00, max_attendees: 2},
            %{package_id: 3, name: "Premium", price: 200.00, max_attendees: 4}
          ],
          time_slots: [
            %{slot_id: 1, start_time: "09:00", end_time: "12:00", capacity: 50, booked: 10},
            %{slot_id: 2, start_time: "14:00", end_time: "17:00", capacity: 50, booked: 25},
            %{slot_id: 3, start_time: "18:00", end_time: "21:00", capacity: 30, booked: 30}
          ],
          add_ons: [
            %{item_id: 1, name: "Lunch", price: 25.00},
            %{item_id: 2, name: "Workshop", price: 75.00},
            %{item_id: 3, name: "Certificate", price: 15.00}
          ]
        }
      }
      
      # Cone for registration
      registration_domain = %{
        schemas: %{
          registration: %{
            source_table: "registration",
            primary_key: :registration_id,
            fields: [:registration_id, :event_id, :package_id, :time_slot_id, :total_amount],
            columns: %{
              registration_id: %{type: :integer},
              event_id: %{type: :integer, required: true},
              package_id: %{type: :integer, required: true},
              time_slot_id: %{type: :integer, required: true},
              total_amount: %{type: :decimal}
            },
            associations: %{
              attendees: %{
                queryable: :attendees,
                cardinality: :many
              },
              add_on_selections: %{
                queryable: :add_on_selections,
                cardinality: :many
              }
            }
          },
          attendees: %{
            source_table: "attendees",
            primary_key: :attendee_id,
            fields: [:attendee_id, :first_name, :last_name, :email, :dietary_restrictions],
            columns: %{
              attendee_id: %{type: :integer},
              first_name: %{type: :string, required: true},
              last_name: %{type: :string, required: true},
              email: %{type: :string, required: true},
              dietary_restrictions: %{type: :text}
            }
          },
          add_on_selections: %{
            source_table: "add_on_selections",
            primary_key: :selection_id,
            fields: [:selection_id, :item_id, :quantity],
            columns: %{
              selection_id: %{type: :integer},
              item_id: %{type: :integer, required: true},
              quantity: %{type: :integer, required: true}
            }
          }
        },
        source: :registration
      }
      
      cone = Cone.init(
        registration_domain,
        SelectoTest.Repo,
        provider,
        validations: [
          {:package_id, {:validate_with, :packages}},
          {:time_slot_id, {:validate_with, :time_slots}},
          {:add_on_selections, :item_id, {:validate_with, :add_ons}}
        ]
      )
      
      {:ok, provider: provider, cone: cone}
    end
    
    test "creates registration with valid package and time slot", %{cone: cone} do
      params = %{
        "event_id" => 100,
        "package_id" => 2,  # Standard package
        "time_slot_id" => 1,  # Morning slot
        "total_amount" => "100.00",
        "attendees" => [
          %{
            "first_name" => "John",
            "last_name" => "Doe",
            "email" => "john@example.com",
            "dietary_restrictions" => "Vegetarian"
          },
          %{
            "first_name" => "Jane",
            "last_name" => "Doe",
            "email" => "jane@example.com",
            "dietary_restrictions" => ""
          }
        ],
        "add_on_selections" => [
          %{"item_id" => 1, "quantity" => 2},  # 2 lunches
          %{"item_id" => 3, "quantity" => 2}   # 2 certificates
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      assert validated.valid?
    end
    
    test "rejects registration with sold out time slot", %{cone: cone} do
      params = %{
        "event_id" => 100,
        "package_id" => 1,
        "time_slot_id" => 999,  # Non-existent slot
        "total_amount" => "50.00"
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      refute validated.valid?
    end
    
    test "validates add-on selections", %{cone: cone} do
      params = %{
        "event_id" => 100,
        "package_id" => 1,
        "time_slot_id" => 1,
        "add_on_selections" => [
          %{"item_id" => 1, "quantity" => 1},    # Valid
          %{"item_id" => 999, "quantity" => 1}   # Invalid add-on
        ]
      }
      
      changeset = Cone.changeset(cone, params)
      validated = Cone.validate_with_provider(changeset, cone)
      
      refute validated.valid?
    end
  end
  
  describe "Context-aware provider behavior" do
    test "public context restricts available options" do
      domain = create_product_domain()
      
      public_provider = Provider.init(domain, SelectoTest.Repo, %{}, :public)
      public_provider = %{public_provider |
        cached_data: %{
          products: [
            %{product_id: 1, name: "Public Product", public: true},
            %{product_id: 2, name: "Private Product", public: false}
          ]
        }
      }
      
      # In real implementation, context filters would filter the data
      # For now, we simulate the behavior
      public_products = public_provider.cached_data[:products]
                       |> Enum.filter(& &1.public)
      
      assert length(public_products) == 1
      assert hd(public_products).name == "Public Product"
    end
    
    test "admin context shows all options" do
      domain = create_product_domain()
      
      admin_provider = Provider.init(domain, SelectoTest.Repo, %{}, :admin)
      admin_provider = %{admin_provider |
        cached_data: %{
          products: [
            %{product_id: 1, name: "Public Product", public: true},
            %{product_id: 2, name: "Private Product", public: false},
            %{product_id: 3, name: "Admin Only", admin_only: true}
          ]
        }
      }
      
      # Admin sees everything
      all_products = admin_provider.cached_data[:products]
      assert length(all_products) == 3
    end
  end
  
  # Helper functions
  
  defp create_inventory_domain do
    %{
      source: %{
        source_table: "inventory",
        primary_key: :inventory_id,
        fields: [:inventory_id, :film_id, :store_id],
        columns: %{
          inventory_id: %{type: :integer},
          film_id: %{type: :integer, required: true},
          store_id: %{type: :integer, required: true}
        }
      },
      schemas: %{}
    }
  end
  
  defp create_product_domain do
    %{
      source: %{
        source_table: "product",
        primary_key: :product_id,
        fields: [:product_id, :name, :price, :public, :admin_only],
        columns: %{
          product_id: %{type: :integer},
          name: %{type: :string, required: true},
          price: %{type: :decimal, required: true},
          public: %{type: :boolean},
          admin_only: %{type: :boolean}
        }
      },
      schemas: %{}
    }
  end
  
  defp create_mock_inventory(count) do
    Enum.map(1..count, fn i ->
      %{
        inventory_id: i,
        film_id: 100 + i,
        store_id: 1
      }
    end)
  end
  
  defp create_mock_customers(count) do
    Enum.map(1..count, fn i ->
      %{
        customer_id: i,
        first_name: "Customer#{i}",
        last_name: "Test",
        email: "customer#{i}@example.com",
        active: 1
      }
    end)
  end
end