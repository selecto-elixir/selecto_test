defmodule SelectoDomeConceptTest do
  use ExUnit.Case, async: false
  
  alias SelectoTest.{Repo, PagilaDomain}
  alias SelectoTest.Store.{Actor}
  alias SelectoDome

  @moduletag timeout: 15_000

  # Use setup_all to share one connection across all tests in this module
  setup_all do
    repo_config = SelectoTest.Repo.config()
    postgrex_opts = [
      username: repo_config[:username],
      password: repo_config[:password],
      hostname: repo_config[:hostname], 
      database: repo_config[:database],
      port: repo_config[:port] || 5432,
      pool_size: 1,
      pool_timeout: 10_000,
      timeout: 10_000
    ]
    
    {:ok, db_conn} = Postgrex.start_link(postgrex_opts)
    
    on_exit(fn -> 
      if Process.alive?(db_conn) do
        GenServer.stop(db_conn, :normal, 2000)
      end
    end)
    
    %{db_conn: db_conn}
  end

  describe "SelectoDome concept validation" do

    test "can create dome from selecto and result", %{db_conn: db_conn} do
      
      # Create simple domain
      domain = %{
        source: %{
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
        name: "Actor",
        joins: %{},
        schemas: %{}
      }

      # Configure Selecto with Postgrex connection
      selecto = Selecto.configure(domain, db_conn)
      |> Selecto.select(["first_name", "last_name", "actor_id"])
      |> Selecto.filter({"actor_id", {"<", 10}})  # Limit to first 10 actors

      # Execute query
      {:ok, result} = Selecto.execute(selecto)
      {rows, columns, aliases} = result
      
      # Verify we have results
      assert is_list(rows)
      assert length(rows) > 0
      assert "first_name" in columns
      assert "last_name" in columns
      assert "actor_id" in columns

      # Create SelectoDome - this tests the core analysis functionality
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)
      
      # Verify dome structure
      assert dome.selecto == selecto
      assert dome.repo == Repo
      assert is_map(dome.result_metadata)
      assert dome.result_metadata.source_table == "actor"
      refute SelectoDome.has_changes?(dome)

      # Test change tracking (without database operations)
      {:ok, dome_with_insert} = SelectoDome.insert(dome, %{
        first_name: "Test",
        last_name: "Actor"
      })

      assert SelectoDome.has_changes?(dome_with_insert)
      {:ok, changes} = SelectoDome.preview_changes(dome_with_insert)
      assert changes.total_changes == 1
      assert length(changes.inserts) == 1

      insert_change = hd(changes.inserts)
      assert insert_change.type == :insert
      assert insert_change.table == "actor"
      assert insert_change.data.first_name == "Test"
      assert insert_change.data.last_name == "Actor"

      # Test multiple change tracking
      {:ok, dome_multi} = SelectoDome.update(dome_with_insert, 1, %{first_name: "Updated"})
      {:ok, dome_multi} = SelectoDome.delete(dome_multi, 2)

      {:ok, multi_changes} = SelectoDome.preview_changes(dome_multi)
      assert multi_changes.total_changes == 3
      assert length(multi_changes.inserts) == 1
      assert length(multi_changes.updates) == 1
      assert length(multi_changes.deletes) == 1

    end

    test "analyzes query metadata correctly", %{db_conn: db_conn} do
      # Simple test of query analysis without database operations

      domain = %{
        source: %{
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
        name: "Actor",
        joins: %{},
        schemas: %{}
      }

      selecto = Selecto.configure(domain, db_conn)
      |> Selecto.select(["first_name", "last_name"])

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      metadata = SelectoDome.metadata(dome)
      
      # Test metadata structure
      assert metadata.source_table == "actor"
      assert is_map(metadata.tables)
      assert is_map(metadata.column_mapping)
      assert is_list(metadata.constraints)
      assert is_map(metadata.result_structure)

      # Test result structure info
      assert is_list(metadata.result_structure.columns)
      assert is_map(metadata.result_structure.aliases)
      assert is_integer(metadata.result_structure.row_count)
      assert metadata.result_structure.row_count > 0

    end

    test "validates change tracking logic", %{db_conn: db_conn} do
      # Test change tracking without database operations
      # This validates the core SelectoDome logic

      domain = %{
        source: %{
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
        name: "Actor",
        joins: %{},
        schemas: %{}
      }

      selecto = Selecto.configure(domain, db_conn)
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {"<", 5}})

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Test change overwriting logic
      {:ok, dome} = SelectoDome.update(dome, 1, %{first_name: "First"})
      {:ok, dome} = SelectoDome.update(dome, 1, %{first_name: "Second"})
      {:ok, dome} = SelectoDome.update(dome, 1, %{first_name: "Final"})

      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 1
      assert length(changes.updates) == 1

      update_change = hd(changes.updates)
      assert update_change.data.first_name == "Final"

      # Test delete overwriting update
      {:ok, dome} = SelectoDome.delete(dome, 1)
      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 1
      assert length(changes.updates) == 0
      assert length(changes.deletes) == 1

    end
  end
end