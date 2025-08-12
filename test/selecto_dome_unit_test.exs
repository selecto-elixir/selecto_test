defmodule SelectoDomeUnitTest do
  use ExUnit.Case, async: true

  alias SelectoDome.{QueryAnalyzer, ChangeTracker}
  alias SelectoTest.Repo

  describe "SelectoDome unit tests (no database)" do
    test "QueryAnalyzer handles list aliases correctly" do
      # Mock selecto structure
      selecto = %{
        config: %{
          source: %{
            source_table: "actor",
            primary_key: :actor_id,
            columns: %{
              actor_id: %{type: :integer},
              first_name: %{type: :string},
              last_name: %{type: :string}
            }
          },
          joins: %{}
        },
        domain: %{
          schemas: %{}
        }
      }

      # Mock result with list aliases (like Selecto actually returns)
      rows = [["John", "Doe", 1], ["Jane", "Smith", 2]]
      columns = ["first_name", "last_name", "actor_id"]
      aliases = ["uuid1", "uuid2", "uuid3"]  # List format like Selecto returns

      # Test the analysis
      {:ok, metadata} = QueryAnalyzer.analyze_query(selecto, {rows, columns, aliases})

      # Verify metadata structure
      assert metadata.source_table == "actor"
      assert is_map(metadata.tables)
      assert is_map(metadata.column_mapping)
      assert is_list(metadata.constraints)
      
      # Verify result structure
      assert metadata.result_structure.columns == columns
      assert is_map(metadata.result_structure.aliases)  # Should be converted to map
      assert metadata.result_structure.row_count == 2

      IO.puts("\n✅ QueryAnalyzer correctly handles list aliases!")
    end

    test "ChangeTracker tracks operations correctly" do
      # Mock metadata
      metadata = %{
        source_table: "actor",
        tables: %{
          "actor" => %{
            table_name: "actor",
            primary_key: "actor_id",
            columns: %{
              "first_name" => %{source_table: "actor", source_column: "first_name", column_type: :string, nullable: true, primary_key: false},
              "last_name" => %{source_table: "actor", source_column: "last_name", column_type: :string, nullable: true, primary_key: false},
              "actor_id" => %{source_table: "actor", source_column: "actor_id", column_type: :integer, nullable: false, primary_key: true}
            }
          }
        }
      }

      # Create new tracker
      tracker = ChangeTracker.new()
      refute ChangeTracker.has_changes?(tracker)

      # Add insert
      {:ok, tracker} = ChangeTracker.add_insert(tracker, %{first_name: "Test", last_name: "Actor"}, metadata)
      assert ChangeTracker.has_changes?(tracker)

      # Add update  
      {:ok, tracker} = ChangeTracker.add_update(tracker, 1, %{first_name: "Updated"}, metadata)

      # Add delete
      {:ok, tracker} = ChangeTracker.add_delete(tracker, 2, metadata)

      # Verify changes
      summary = ChangeTracker.summarize_changes(tracker)
      assert summary.total_changes == 3
      assert length(summary.inserts) == 1
      assert length(summary.updates) == 1
      assert length(summary.deletes) == 1

      IO.puts("\n✅ ChangeTracker correctly tracks all operation types!")

      # Test change overwriting
      {:ok, tracker} = ChangeTracker.add_update(tracker, 1, %{first_name: "Final"}, metadata)
      summary = ChangeTracker.summarize_changes(tracker)
      assert summary.total_changes == 3  # Same total, but update was overwritten

      update_change = hd(summary.updates)
      assert update_change.data.first_name == "Final"

      IO.puts("✅ ChangeTracker correctly overwrites changes for same record!")

      # Test delete overwriting update
      {:ok, tracker} = ChangeTracker.add_delete(tracker, 1, metadata)
      summary = ChangeTracker.summarize_changes(tracker)
      assert summary.total_changes == 3  # Insert + Delete(1) + Delete(2) = 3 total
      assert length(summary.updates) == 0  # Update was overwritten by delete
      assert length(summary.deletes) == 2  # Delete(1) and Delete(2)

      IO.puts("✅ ChangeTracker correctly handles delete overwriting update!")
    end

    test "SelectoDome API structure validation" do
      # Test that we can create the main structures without database
      
      # Mock a complete selecto structure
      selecto = %{
        config: %{
          source: %{
            source_table: "actor",
            primary_key: :actor_id,
            columns: %{
              actor_id: %{type: :integer},
              first_name: %{type: :string}
            }
          },
          joins: %{}
        },
        domain: %{schemas: %{}}
      }

      # Mock result
      result = {[["John", 1]], ["first_name", "actor_id"], ["uuid1", "uuid2"]}

      # Test analysis
      {:ok, metadata} = QueryAnalyzer.analyze_query(selecto, result)
      
      # Create mock dome structure
      dome = %SelectoDome{
        selecto: selecto,
        result_metadata: metadata,
        changes: ChangeTracker.new(),
        repo: Repo
      }

      # Test basic operations
      {:ok, dome_with_insert} = SelectoDome.insert(dome, %{first_name: "Test"})
      assert SelectoDome.has_changes?(dome_with_insert)

      {:ok, changes} = SelectoDome.preview_changes(dome_with_insert)
      assert changes.total_changes == 1

      # Test metadata access
      assert SelectoDome.selecto(dome) == selecto
      assert SelectoDome.metadata(dome) == metadata
      refute SelectoDome.has_changes?(dome)
      assert SelectoDome.has_changes?(dome_with_insert)

      IO.puts("\n✅ SelectoDome API structure works correctly!")
    end

    test "demonstrates SelectoDome core functionality without database" do
      IO.puts("\n=== SelectoDome Core Functionality Demo ===")
      
      # This test demonstrates that SelectoDome works correctly
      # even without actual database operations
      
      selecto = %{
        config: %{
          source: %{
            source_table: "users",
            primary_key: :id,
            columns: %{
              id: %{type: :integer},
              name: %{type: :string},
              email: %{type: :string}
            }
          },
          joins: %{}
        },
        domain: %{schemas: %{}}
      }

      # Simulate a query result
      result = {
        [["John Doe", "john@example.com", 1], ["Jane Smith", "jane@example.com", 2]],
        ["name", "email", "id"],
        ["alias1", "alias2", "alias3"]
      }

      IO.puts("1. Analyzing query structure...")
      {:ok, metadata} = QueryAnalyzer.analyze_query(selecto, result)
      IO.puts("   ✅ Source table: #{metadata.source_table}")
      IO.puts("   ✅ Columns mapped: #{length(Map.keys(metadata.column_mapping))}")
      IO.puts("   ✅ Row count: #{metadata.result_structure.row_count}")

      IO.puts("2. Creating SelectoDome...")
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)
      IO.puts("   ✅ Dome created successfully")

      IO.puts("3. Performing data operations...")
      {:ok, dome} = SelectoDome.insert(dome, %{name: "New User", email: "new@example.com"})
      {:ok, dome} = SelectoDome.update(dome, 1, %{name: "Updated John"})
      {:ok, dome} = SelectoDome.delete(dome, 2)
      IO.puts("   ✅ Insert, Update, Delete operations tracked")

      IO.puts("4. Previewing changes...")
      {:ok, changes} = SelectoDome.preview_changes(dome)
      IO.puts("   ✅ Total changes: #{changes.total_changes}")
      IO.puts("   ✅ Inserts: #{length(changes.inserts)}")
      IO.puts("   ✅ Updates: #{length(changes.updates)}")  
      IO.puts("   ✅ Deletes: #{length(changes.deletes)}")

      IO.puts("5. Validating change details...")
      insert_change = hd(changes.inserts)
      update_change = hd(changes.updates)
      delete_change = hd(changes.deletes)

      assert insert_change.type == :insert
      assert insert_change.data.name == "New User"
      assert update_change.type == :update
      assert update_change.id == 1
      assert delete_change.type == :delete
      assert delete_change.id == 2

      IO.puts("   ✅ All change details correct")
      
      IO.puts("\n🎉 SelectoDome core functionality working perfectly!")
      IO.puts("==========================================\n")
    end
  end
end