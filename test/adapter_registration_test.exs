defmodule AdapterRegistrationTest do
  use ExUnit.Case
  
  alias Selecto.Database.Registry
  alias Selecto.Database.Features
  
  describe "adapter registration" do
    test "PostgreSQL adapter is available" do
      assert Code.ensure_loaded?(Selecto.Adapters.PostgreSQL)
    end
    
    test "PostgreSQL adapter implements required callbacks" do
      adapter = Selecto.Adapters.PostgreSQL
      
      # Check that all required callbacks are exported
      assert function_exported?(adapter, :connect, 1)
      assert function_exported?(adapter, :disconnect, 1)
      assert function_exported?(adapter, :execute, 4)
      assert function_exported?(adapter, :quote_identifier, 1)
      assert function_exported?(adapter, :supports?, 1)
      assert function_exported?(adapter, :capabilities, 0)
    end
    
    test "PostgreSQL adapter supports required features" do
      adapter = Selecto.Adapters.PostgreSQL
      capabilities = adapter.capabilities()
      
      # Check required features
      assert Features.validate_required_features(capabilities) == :ok
      
      # Check some PostgreSQL-specific features
      assert adapter.supports?(:lateral_join)
      assert adapter.supports?(:window_functions)
      assert adapter.supports?(:cte)
      assert adapter.supports?(:arrays)
    end
  end
  
  describe "MySQL adapter" do
    @moduletag :mysql
    
    test "MySQL adapter can be loaded" do
      # The MySQL adapter is in a separate package
      # It would need to be compiled first
      assert Code.ensure_loaded(Selecto.DB.MySQL) == {:module, Selecto.DB.MySQL}
    end
    
    test "MySQL adapter capabilities" do
      adapter = Selecto.DB.MySQL
      capabilities = adapter.capabilities()
      
      # MySQL doesn't support some PostgreSQL features
      refute Map.get(capabilities, :full_outer_join)
      refute Map.get(capabilities, :arrays)
      refute Map.get(capabilities, :returning)
      
      # But it does support these
      assert Map.get(capabilities, :json)
      assert Map.get(capabilities, :fulltext_search)
    end
    
    test "MySQL parameter conversion" do
      # MySQL uses ? instead of $1, $2
      assert Selecto.DB.MySQL.parameter_placeholder(1) == "?"
      assert Selecto.DB.MySQL.parameter_placeholder(2) == "?"
    end
    
    test "MySQL identifier quoting" do
      assert Selecto.DB.MySQL.quote_identifier("table") == "`table`"
      assert Selecto.DB.MySQL.quote_identifier("col`umn") == "`col``umn`"
    end
  end
  
  describe "SQLite adapter" do
    @moduletag :sqlite
    
    test "SQLite adapter can be loaded" do
      assert Code.ensure_loaded(Selecto.DB.SQLite) == {:module, Selecto.DB.SQLite}
    end
    
    test "SQLite adapter capabilities" do
      adapter = Selecto.DB.SQLite
      capabilities = adapter.capabilities()
      
      # SQLite limitations
      refute Map.get(capabilities, :right_join)
      refute Map.get(capabilities, :full_outer_join)
      refute Map.get(capabilities, :stored_procedures)
      
      # SQLite features
      assert Map.get(capabilities, :cte)
      assert Map.get(capabilities, :recursive_cte)
      assert Map.get(capabilities, :returning)
      assert Map.get(capabilities, :in_memory)
    end
    
    test "SQLite type mappings" do
      adapter = Selecto.DB.SQLite
      
      # SQLite uses TEXT for most string types
      assert adapter.type_name(:string) == "TEXT"
      assert adapter.type_name(:uuid) == "TEXT"
      assert adapter.type_name(:date) == "TEXT"
      
      # Numeric types
      assert adapter.type_name(:integer) == "INTEGER"
      assert adapter.type_name(:float) == "REAL"
      assert adapter.type_name(:boolean) == "INTEGER"
    end
    
    test "SQLite boolean encoding" do
      adapter = Selecto.DB.SQLite
      
      assert adapter.encode_type(true, :boolean) == 1
      assert adapter.encode_type(false, :boolean) == 0
      
      assert adapter.decode_type(1, :boolean) == true
      assert adapter.decode_type(0, :boolean) == false
    end
  end
  
  describe "adapter discovery" do
    test "feature detection works across adapters" do
      pg_adapter = Selecto.Adapters.PostgreSQL
      
      # PostgreSQL supports everything
      assert Features.supports?(pg_adapter, :lateral_join)
      assert Features.supports?(pg_adapter, :arrays)
      
      # Test feature categories
      categories = Features.feature_categories()
      assert Map.has_key?(categories, :joins)
      assert Map.has_key?(categories, :advanced_sql)
      assert Map.has_key?(categories, :data_types)
    end
    
    test "feature emulation suggestions" do
      # Some features can be emulated
      assert {:ok, :union_all} = Features.emulation_strategy(:full_outer_join)
      assert {:ok, :left_join_reverse} = Features.emulation_strategy(:right_join)
      assert {:error, :no_emulation} = Features.emulation_strategy(:lateral_join)
    end
  end
end