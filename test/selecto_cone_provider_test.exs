defmodule SelectoCone.ProviderTest do
  use SelectoTest.DataCase
  
  alias SelectoCone.Core.Provider
  
  describe "Provider initialization" do
    test "creates provider with base filters and context" do
      domain = create_film_domain()
      
      provider = Provider.init(
        domain,
        SelectoTest.Repo,
        %{rating: "PG"},
        :public
      )
      
      assert provider.domain == domain
      assert provider.repo == SelectoTest.Repo
      assert provider.context == :public
      assert provider.base_filters == %{rating: "PG"}
      assert provider.context_filters == [
        {:published, {:eq, true}},
        {:available, {:eq, true}}
      ]
    end
    
    test "admin context has no additional filters" do
      domain = create_film_domain()
      
      provider = Provider.init(domain, SelectoTest.Repo, %{}, :admin)
      
      assert provider.context == :admin
      assert provider.context_filters == []
    end
    
    test "api context has specific filters" do
      domain = create_film_domain()
      
      provider = Provider.init(domain, SelectoTest.Repo, %{}, :api)
      
      assert provider.context == :api
      assert provider.context_filters == [{:api_accessible, {:eq, true}}]
    end
  end
  
  describe "Provider data queries" do
    test "sets data query function" do
      provider = create_basic_provider()
      
      query_fn = fn selecto ->
        selecto
        |> Selecto.select([:film_id, :title, :rating])
        |> Selecto.subselect(
          ["actor.actor_id", "actor.first_name", "actor.last_name"],
          format: :json_agg,
          alias: :available_actors
        )
      end
      
      updated = Provider.set_data_query(provider, query_fn)
      
      assert updated.data_query != nil
      assert updated.cached_data == %{}
      assert updated.cache_timestamp == nil
    end
    
    test "get_all_data returns error when no query configured" do
      provider = create_basic_provider()
      
      result = Provider.get_all_data(provider)
      
      assert result == {:error, "No data query configured for provider"}
    end
    
    test "get_available_options returns empty list when no data" do
      provider = create_basic_provider()
      
      options = Provider.get_available_options(provider, :films)
      
      assert options == []
    end
    
    test "get_available_options returns cached data" do
      provider = %Provider{
        cached_data: %{
          films: [
            %{film_id: 1, title: "Film 1"},
            %{film_id: 2, title: "Film 2"}
          ]
        }
      }
      
      options = Provider.get_available_options(provider, :films)
      
      assert length(options) == 2
      assert Enum.at(options, 0).title == "Film 1"
    end
  end
  
  describe "Provider validation" do
    test "validate_selection succeeds with valid IDs" do
      provider = %Provider{
        cached_data: %{
          inventory: [
            %{id: 1, film_id: 101},
            %{id: 2, film_id: 102},
            %{id: 3, film_id: 103}
          ]
        }
      }
      
      result = Provider.validate_selection(provider, :inventory, [1, 2])
      
      assert result == :ok
    end
    
    test "validate_selection fails with invalid IDs" do
      provider = %Provider{
        cached_data: %{
          inventory: [
            %{id: 1, film_id: 101},
            %{id: 2, film_id: 102}
          ]
        }
      }
      
      result = Provider.validate_selection(provider, :inventory, [1, 5, 10])
      
      assert {:error, message} = result
      assert message =~ "invalid inventory"
      assert message =~ "[5, 10]"
    end
    
    test "validate_selection handles different ID field patterns" do
      provider = %Provider{
        cached_data: %{
          packages: [
            %{package_id: 1, name: "Basic"},
            %{package_id: 2, name: "Premium"}
          ],
          items: [
            %{item_id: 10, name: "Item A"},
            %{item_id: 20, name: "Item B"}
          ],
          slots: [
            %{slot_id: 100, time: "10:00"},
            %{slot_id: 200, time: "14:00"}
          ]
        }
      }
      
      # Test with package_id field
      assert Provider.validate_selection(provider, :packages, [1, 2]) == :ok
      assert {:error, _} = Provider.validate_selection(provider, :packages, [3])
      
      # Test with item_id field
      assert Provider.validate_selection(provider, :items, [10, 20]) == :ok
      assert {:error, _} = Provider.validate_selection(provider, :items, [30])
      
      # Test with slot_id field
      assert Provider.validate_selection(provider, :slots, [100]) == :ok
      assert {:error, _} = Provider.validate_selection(provider, :slots, [300])
    end
    
    test "validate_selection returns ok when no options available (no restriction)" do
      provider = %Provider{cached_data: %{}}
      
      result = Provider.validate_selection(provider, :anything, [1, 2, 3])
      
      assert result == :ok
    end
  end
  
  describe "Provider context and filter updates" do
    test "with_context updates context and clears cache" do
      domain = create_film_domain()
      provider = Provider.init(domain, SelectoTest.Repo, %{store_id: 1}, :public)
      
      # Add some cached data
      provider = %{provider | 
        cached_data: %{films: [%{id: 1}]},
        cache_timestamp: DateTime.utc_now()
      }
      
      # Change context
      updated = Provider.with_context(provider, :admin)
      
      assert updated.context == :admin
      assert updated.context_filters == []
      assert updated.cached_data == %{}
      assert updated.cache_timestamp == nil
    end
    
    test "with_filters updates base filters and clears cache" do
      domain = create_film_domain()
      provider = Provider.init(domain, SelectoTest.Repo, %{store_id: 1}, :public)
      
      # Add some cached data
      provider = %{provider | 
        cached_data: %{films: [%{id: 1}]},
        cache_timestamp: DateTime.utc_now()
      }
      
      # Update filters
      updated = Provider.with_filters(provider, %{rating: "R", length: 120})
      
      assert updated.base_filters == %{store_id: 1, rating: "R", length: 120}
      assert updated.cached_data == %{}
      assert updated.cache_timestamp == nil
    end
    
    test "clear_cache removes cached data" do
      provider = %Provider{
        cached_data: %{films: [%{id: 1}]},
        cache_timestamp: DateTime.utc_now()
      }
      
      cleared = Provider.clear_cache(provider)
      
      assert cleared.cached_data == %{}
      assert cleared.cache_timestamp == nil
    end
  end
  
  describe "Provider with complex domain" do
    test "handles rental domain with multiple associations" do
      domain = create_rental_domain()
      
      provider = Provider.init(
        domain,
        SelectoTest.Repo,
        %{store_id: 1},
        :public
      )
      
      # Set up a complex query with subselects
      query_fn = fn selecto ->
        selecto
        |> Selecto.select([:inventory_id, :film_id, :store_id])
        |> Selecto.subselect(
          ["film.film_id", "film.title", "film.rating", "film.rental_rate"],
          format: :json_agg,
          alias: :available_films
        )
        |> Selecto.subselect(
          ["customer.customer_id", "customer.first_name", "customer.last_name"],
          format: :json_agg,
          alias: :available_customers,
          filter: [{:active, {:eq, true}}]
        )
      end
      
      provider_with_query = Provider.set_data_query(provider, query_fn)
      
      assert provider_with_query.data_query != nil
      assert provider_with_query.domain == domain
    end
  end
  
  # Helper functions
  
  defp create_film_domain do
    %{
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
      },
      schemas: %{},
      name: "Film"
    }
  end
  
  defp create_rental_domain do
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
      schemas: %{},
      name: "Inventory"
    }
  end
  
  defp create_basic_provider do
    Provider.init(
      create_film_domain(),
      SelectoTest.Repo,
      %{},
      :public
    )
  end
end