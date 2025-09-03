defmodule ConnectionAbstractionTest do
  use ExUnit.Case
  alias Selecto.Connection
  alias Selecto.Database.{Registry, Features}
  
  describe "backward compatibility" do
    test "Selecto.configure works without adapter option (defaults to PostgreSQL)" do
      domain = %{
        source: %{
          source_table: "users",
          primary_key: :id,
          fields: [:id, :name],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string}
          }
        },
        schemas: %{}
      }
      
      # Mock postgrex options
      postgrex_opts = [
        hostname: "localhost",
        database: "test_db"
      ]
      
      # This should work without specifying adapter
      selecto = Selecto.configure(domain, postgrex_opts, validate: false)
      
      assert selecto.adapter == Selecto.DB.PostgreSQL
      assert selecto.postgrex_opts == postgrex_opts
    end
    
    test "existing PostgreSQL code continues to work" do
      domain = %{
        source: %{
          source_table: "films",
          primary_key: :film_id,
          fields: [:film_id, :title],
          columns: %{
            film_id: %{type: :integer},
            title: %{type: :string}
          }
        },
        schemas: %{}
      }
      
      postgrex_opts = [hostname: "localhost", database: "test"]
      
      # Old way should still work
      selecto = Selecto.configure(domain, postgrex_opts, validate: false)
      
      # Verify it's set up correctly
      assert %Selecto{} = selecto
      assert selecto.domain == domain
      assert selecto.adapter == Selecto.DB.PostgreSQL
    end
  end
  
  describe "adapter discovery" do
    test "discovers available adapters" do
      adapters = Connection.discover_adapters()
      
      # Should at least have PostgreSQL
      assert Enum.any?(adapters, fn a -> a.module == Selecto.DB.PostgreSQL end)
      
      # Check structure
      for adapter <- adapters do
        assert Map.has_key?(adapter, :module)
        assert Map.has_key?(adapter, :name)
        assert Map.has_key?(adapter, :dialect)
      end
    end
    
    test "adapter_available? correctly identifies available adapters" do
      assert Connection.adapter_available?(Selecto.DB.PostgreSQL)
      
      # Non-existent adapter
      refute Connection.adapter_available?(NonExistent.Adapter)
    end
    
    test "default_adapter returns PostgreSQL" do
      assert Connection.default_adapter() == Selecto.DB.PostgreSQL
    end
  end
  
  describe "adapter configuration" do
    test "can configure with SQLite adapter" do
      domain = %{
        source: %{
          source_table: "users",
          primary_key: :id,
          fields: [:id, :name],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string}
          }
        },
        schemas: %{}
      }
      
      # Configure with SQLite adapter
      if Code.ensure_loaded?(Selecto.DB.SQLite) do
        config = [database: ":memory:"]
        selecto = Selecto.configure(domain, config, 
          adapter: Selecto.DB.SQLite,
          validate: false
        )
        
        assert selecto.adapter == Selecto.DB.SQLite
      end
    end
    
    test "can configure with MySQL adapter" do
      domain = %{
        source: %{
          source_table: "users",
          primary_key: :id,
          fields: [:id, :name],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string}
          }
        },
        schemas: %{}
      }
      
      # Configure with MySQL adapter
      if Code.ensure_loaded?(Selecto.DB.MySQL) do
        config = [
          hostname: "localhost",
          username: "root",
          database: "test"
        ]
        
        selecto = Selecto.configure(domain, config,
          adapter: Selecto.DB.MySQL,
          validate: false
        )
        
        assert selecto.adapter == Selecto.DB.MySQL
      end
    end
  end
  
  describe "connection interface" do
    test "connect delegates to adapter" do
      # Test with mock adapter
      opts = [database: "test"]
      
      # PostgreSQL adapter should be available
      result = Connection.connect(Selecto.DB.PostgreSQL, opts)
      assert {:ok, _conn} = result
    end
    
    test "execute delegates to adapter" do
      opts = [database: "test"]
      {:ok, conn} = Connection.connect(Selecto.DB.PostgreSQL, opts)
      
      # Mock query execution
      result = Connection.execute(
        Selecto.DB.PostgreSQL,
        conn,
        "SELECT 1",
        []
      )
      
      assert {:ok, _result} = result
    end
    
    test "returns error for unsupported adapter methods" do
      # Create a minimal adapter that doesn't implement execute
      defmodule MinimalAdapter do
        def connect(_opts), do: {:ok, %{}}
      end
      
      opts = [database: "test"]
      {:ok, conn} = Connection.connect(MinimalAdapter, opts)
      
      result = Connection.execute(MinimalAdapter, conn, "SELECT 1", [])
      assert {:error, {:adapter_error, _}} = result
    end
  end
  
  describe "adapter dialect detection" do
    test "gets correct dialect for known adapters" do
      assert Connection.adapter_dialect(Selecto.DB.PostgreSQL) == "postgresql"
      
      if Code.ensure_loaded?(Selecto.DB.SQLite) do
        assert Connection.adapter_dialect(Selecto.DB.SQLite) == "sqlite"
      end
      
      if Code.ensure_loaded?(Selecto.DB.MySQL) do
        assert Connection.adapter_dialect(Selecto.DB.MySQL) == "mysql"
      end
    end
    
    test "gets adapter name" do
      assert Connection.adapter_name(Selecto.DB.PostgreSQL) == "PostgreSQL"
      
      if Code.ensure_loaded?(Selecto.DB.SQLite) do
        assert Connection.adapter_name(Selecto.DB.SQLite) == "SQLite"
      end
      
      if Code.ensure_loaded?(Selecto.DB.MySQL) do
        assert Connection.adapter_name(Selecto.DB.MySQL) == "MySQL"
      end
    end
  end
  
  describe "feature detection through adapters" do
    test "PostgreSQL adapter supports all features" do
      adapter = Selecto.DB.PostgreSQL
      
      # Should support advanced features
      assert Features.supports?(adapter, :cte)
      assert Features.supports?(adapter, :window_functions)
      assert Features.supports?(adapter, :lateral_join)
      assert Features.supports?(adapter, :arrays)
    end
    
    test "SQLite adapter has limited features" do
      if Code.ensure_loaded?(Selecto.DB.SQLite) do
        adapter = Selecto.DB.SQLite
        
        # Should support basic features
        assert Features.supports?(adapter, :select)
        assert Features.supports?(adapter, :inner_join)
        assert Features.supports?(adapter, :left_join)
        
        # Should not support some advanced features
        refute Features.supports?(adapter, :right_join)
        refute Features.supports?(adapter, :full_outer_join)
        refute Features.supports?(adapter, :lateral_join)
      end
    end
    
    test "MySQL adapter has intermediate features" do
      if Code.ensure_loaded?(Selecto.DB.MySQL) do
        adapter = Selecto.DB.MySQL
        
        # Should support most features
        assert Features.supports?(adapter, :select)
        assert Features.supports?(adapter, :inner_join)
        assert Features.supports?(adapter, :left_join)
        assert Features.supports?(adapter, :right_join)
        
        # Limited support for some features
        refute Features.supports?(adapter, :full_outer_join)
        # MySQL 8.0.14+ supports LATERAL joins
        assert Features.supports?(adapter, :lateral_join)
      end
    end
  end
end