defmodule SelectoDomeConceptTest do
  use SelectoTest.SelectoCase, async: false
  
  alias SelectoDome

  @moduletag timeout: 15_000

  describe "SelectoDome concept validation" do

    test "can create dome from selecto and result" do
      # Insert test data
      _test_data = insert_test_data!()
      
      # Debug: Check if data was inserted
      count_result = SelectoTest.Repo.query!("SELECT COUNT(*) FROM actor")
      IO.puts("Actor count via Ecto: #{inspect(count_result)}")
      
      # Check what actor IDs we actually have
      actors_result = SelectoTest.Repo.query!("SELECT actor_id, first_name, last_name FROM actor ORDER BY actor_id")
      IO.puts("Actual actors: #{inspect(actors_result)}")
      
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
      selecto = Selecto.configure(domain, SelectoTest.Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])
      |> Selecto.filter({"actor_id", {"<", 10}})  # Limit to first 10 actors

      # Execute query
      result = Selecto.execute(selecto)
      IO.puts("Selecto execute result: #{inspect(result)}")
      
      {rows, columns, aliases} = case result do
        {:ok, {rows, columns, aliases}} -> 
          IO.puts("Selecto found #{length(rows)} rows")
          {rows, columns, aliases}
        {:error, error} ->
          IO.puts("Selecto error: #{inspect(error)}")
          raise "Selecto query failed: #{inspect(error)}"
      end
      
      # Verify we have results
      assert is_list(rows)
      assert length(rows) > 0
      assert "first_name" in columns
      assert "last_name" in columns
      assert "actor_id" in columns

      # Create SelectoDome - this tests the core analysis functionality
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)
      
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

    test "analyzes query metadata correctly" do
      # Insert test data
      _test_data = insert_test_data!()
      
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

      selecto = Selecto.configure(domain, SelectoTest.Repo)
      |> Selecto.select(["first_name", "last_name"])

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

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

    test "validates change tracking logic" do
      # Insert test data
      _test_data = insert_test_data!()
      
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

      selecto = Selecto.configure(domain, SelectoTest.Repo)
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {"<", 5}})

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

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