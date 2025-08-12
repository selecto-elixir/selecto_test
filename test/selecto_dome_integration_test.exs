defmodule SelectoDomeIntegrationTest do
  use SelectoTest.DataCase
  
  alias SelectoTest.{Repo, PagilaDomain}
  alias SelectoTest.Store.{Actor, Film, Language}
  alias SelectoDome

  describe "SelectoDome with Pagila Actor domain" do
    setup do
      # Create some test data
      {:ok, english} = %Language{name: "English"} |> Repo.insert()
      
      {:ok, actor1} = %Actor{first_name: "John", last_name: "Doe"} |> Repo.insert()
      {:ok, actor2} = %Actor{first_name: "Jane", last_name: "Smith"} |> Repo.insert()
      
      {:ok, film1} = %Film{
        title: "Test Film 1",
        description: "A test film",
        release_year: 2023,
        language_id: english.language_id,
        rental_duration: 3,
        rental_rate: Decimal.new("4.99"),
        length: 120,
        replacement_cost: Decimal.new("19.99"),
        rating: :PG
      } |> Repo.insert()

      # Set up Selecto with Pagila actor domain
      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])

      %{
        selecto: selecto,
        domain: domain,
        actor1: actor1,
        actor2: actor2,
        film1: film1,
        english: english
      }
    end

    test "creates dome from Selecto query result", %{selecto: selecto} do
      # Execute query
      {:ok, result} = Selecto.execute(selecto)
      {rows, columns, aliases} = result
      
      assert length(rows) >= 2  # At least our test actors
      assert "first_name" in columns
      assert "last_name" in columns
      assert "actor_id" in columns

      # Create SelectoDome
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)
      
      assert dome.selecto == selecto
      assert dome.repo == Repo
      assert dome.result_metadata.source_table == "actor"
      refute SelectoDome.has_changes?(dome)
    end

    test "inserts new actor that satisfies query constraints", %{selecto: selecto} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Insert a new actor
      new_actor_attrs = %{
        first_name: "Alice",
        last_name: "Johnson"
      }

      {:ok, dome_with_insert} = SelectoDome.insert(dome, new_actor_attrs)
      assert SelectoDome.has_changes?(dome_with_insert)

      # Preview changes
      {:ok, changes} = SelectoDome.preview_changes(dome_with_insert)
      assert changes.total_changes == 1
      assert length(changes.inserts) == 1
      assert length(changes.updates) == 0
      assert length(changes.deletes) == 0

      # Check the insert details
      insert_change = hd(changes.inserts)
      assert insert_change.type == :insert
      assert insert_change.table == "actor"
      assert insert_change.data.first_name == "Alice"
      assert insert_change.data.last_name == "Johnson"
    end

    test "commits insert operation to database", %{selecto: selecto} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      initial_count = length(elem(result, 0))

      # Insert and commit
      {:ok, dome_with_insert} = SelectoDome.insert(dome, %{
        first_name: "Bob",
        last_name: "Wilson"
      })

      {:ok, updated_result} = SelectoDome.commit(dome_with_insert)
      {updated_rows, updated_columns, _updated_aliases} = updated_result

      # Verify the new actor appears in the updated result
      assert length(updated_rows) == initial_count + 1
      assert updated_columns == elem(result, 1)  # Same columns

      # Verify actor exists in database
      bob_actor = Repo.get_by(Actor, first_name: "Bob", last_name: "Wilson")
      assert bob_actor != nil
      assert bob_actor.first_name == "Bob"
      assert bob_actor.last_name == "Wilson"
    end

    test "updates existing actor", %{selecto: selecto, actor1: actor1} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Update actor1's name
      update_attrs = %{first_name: "Johnny"}
      {:ok, dome_with_update} = SelectoDome.update(dome, actor1.actor_id, update_attrs)

      assert SelectoDome.has_changes?(dome_with_update)

      # Preview changes
      {:ok, changes} = SelectoDome.preview_changes(dome_with_update)
      assert changes.total_changes == 1
      assert length(changes.updates) == 1

      update_change = hd(changes.updates)
      assert update_change.type == :update
      assert update_change.id == actor1.actor_id
      assert update_change.data.first_name == "Johnny"
    end

    test "commits update operation to database", %{selecto: selecto, actor1: actor1} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Update and commit
      {:ok, dome_with_update} = SelectoDome.update(dome, actor1.actor_id, %{
        first_name: "Updated John"
      })

      {:ok, updated_result} = SelectoDome.commit(dome_with_update)
      {updated_rows, _columns, _aliases} = updated_result

      # Verify the update appears in the result
      updated_actor_row = Enum.find(updated_rows, fn row ->
        actor_id_index = 2  # actor_id is the 3rd column (0-indexed)
        Enum.at(row, actor_id_index) == actor1.actor_id
      end)

      assert updated_actor_row != nil
      assert Enum.at(updated_actor_row, 0) == "Updated John"  # first_name is first column

      # Verify actor is updated in database
      updated_actor = Repo.get(Actor, actor1.actor_id)
      assert updated_actor.first_name == "Updated John"
      assert updated_actor.last_name == actor1.last_name  # Unchanged
    end

    test "deletes existing actor", %{selecto: selecto, actor2: actor2} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      initial_count = length(elem(result, 0))

      # Delete actor2
      {:ok, dome_with_delete} = SelectoDome.delete(dome, actor2.actor_id)

      assert SelectoDome.has_changes?(dome_with_delete)

      # Preview changes
      {:ok, changes} = SelectoDome.preview_changes(dome_with_delete)
      assert changes.total_changes == 1
      assert length(changes.deletes) == 1

      delete_change = hd(changes.deletes)
      assert delete_change.type == :delete
      assert delete_change.id == actor2.actor_id
    end

    test "commits delete operation to database", %{selecto: selecto, actor2: actor2} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      initial_count = length(elem(result, 0))

      # Delete and commit
      {:ok, dome_with_delete} = SelectoDome.delete(dome, actor2.actor_id)
      {:ok, updated_result} = SelectoDome.commit(dome_with_delete)

      {updated_rows, _columns, _aliases} = updated_result

      # Verify the actor is removed from the result
      assert length(updated_rows) == initial_count - 1

      # Verify actor is deleted from database
      deleted_actor = Repo.get(Actor, actor2.actor_id)
      assert deleted_actor == nil
    end

    test "handles multiple operations in sequence", %{selecto: selecto, actor1: actor1} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      initial_count = length(elem(result, 0))

      # Chain multiple operations
      {:ok, dome} = SelectoDome.insert(dome, %{first_name: "Charlie", last_name: "Brown"})
      {:ok, dome} = SelectoDome.insert(dome, %{first_name: "Diana", last_name: "Prince"})
      {:ok, dome} = SelectoDome.update(dome, actor1.actor_id, %{first_name: "Updated John"})

      # Preview all changes
      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 3
      assert length(changes.inserts) == 2
      assert length(changes.updates) == 1
      assert length(changes.deletes) == 0

      # Commit all changes
      {:ok, updated_result} = SelectoDome.commit(dome)
      {updated_rows, _columns, _aliases} = updated_result

      # Verify the result reflects all changes
      assert length(updated_rows) == initial_count + 2  # 2 new actors added

      # Verify in database
      charlie = Repo.get_by(Actor, first_name: "Charlie", last_name: "Brown")
      diana = Repo.get_by(Actor, first_name: "Diana", last_name: "Prince")
      updated_actor1 = Repo.get(Actor, actor1.actor_id)

      assert charlie != nil
      assert diana != nil
      assert updated_actor1.first_name == "Updated John"
    end
  end

  describe "SelectoDome query consistency validation" do
    setup do
      {:ok, english} = %Language{name: "English"} |> Repo.insert()
      
      # Create a filtered query - only actors whose names start with 'J'
      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])
      |> Selecto.filter([{"first_name", {:like, "J%"}}])

      %{selecto: selecto, domain: domain, english: english}
    end

    test "validates insert satisfies query constraints", %{selecto: selecto} do
      # Create some test data that matches the filter
      {:ok, john} = %Actor{first_name: "John", last_name: "Doe"} |> Repo.insert()
      {:ok, jane} = %Actor{first_name: "Jane", last_name: "Smith"} |> Repo.insert()

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # This should work - name starts with 'J'
      {:ok, _dome} = SelectoDome.insert(dome, %{
        first_name: "Jack",
        last_name: "Johnson"
      })

      # Note: In a more advanced implementation, we might validate that inserts
      # satisfy the query constraints, but for now we focus on the basic API
    end

    test "allows updates that maintain query consistency", %{selecto: selecto} do
      {:ok, john} = %Actor{first_name: "John", last_name: "Doe"} |> Repo.insert()

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Update to another name starting with 'J' - should be fine
      {:ok, dome} = SelectoDome.update(dome, john.actor_id, %{first_name: "James"})
      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify the change was applied
      updated_john = Repo.get(Actor, john.actor_id)
      assert updated_john.first_name == "James"
    end
  end

  describe "SelectoDome with complex joins" do
    setup do
      {:ok, english} = %Language{name: "English"} |> Repo.insert()
      {:ok, spanish} = %Language{name: "Spanish"} |> Repo.insert()
      
      {:ok, actor} = %Actor{first_name: "Tom", last_name: "Hanks"} |> Repo.insert()
      
      {:ok, film} = %Film{
        title: "Test Movie",
        description: "A great film",
        release_year: 2023,
        language_id: english.language_id,
        rental_duration: 5,
        rental_rate: Decimal.new("3.99"),
        length: 150,
        replacement_cost: Decimal.new("24.99"),
        rating: :PG
      } |> Repo.insert()

      # Create join query that includes film information
      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "film[title]", "film[rating]"])
      |> Selecto.join(:film_actors, %{film: %{}})

      %{
        selecto: selecto,
        actor: actor,
        film: film,
        english: english,
        spanish: spanish
      }
    end

    test "analyzes joined query structure", %{selecto: selecto} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      metadata = SelectoDome.metadata(dome)
      assert metadata.source_table == "actor"
      
      # Should recognize multiple tables involved
      assert Map.has_key?(metadata.tables, "actor")
      # Note: The join analysis might need refinement based on how Selecto structures joins
    end

    test "handles operations with joins present", %{selecto: selecto} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Insert a new actor (should work even with joins in the query)
      {:ok, dome} = SelectoDome.insert(dome, %{
        first_name: "Morgan",
        last_name: "Freeman"
      })

      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 1
      assert length(changes.inserts) == 1

      # Commit should work
      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify the actor was created
      morgan = Repo.get_by(Actor, first_name: "Morgan", last_name: "Freeman")
      assert morgan != nil
    end
  end

  describe "SelectoDome error handling" do
    setup do
      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])

      %{selecto: selecto}
    end

    test "handles invalid field types gracefully", %{selecto: selecto} do
      {:ok, actor} = %Actor{first_name: "Test", last_name: "Actor"} |> Repo.insert()
      
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Try to insert with invalid data types - should be handled gracefully
      # Note: The current implementation is permissive, but we can test basic validation
      {:ok, _dome} = SelectoDome.insert(dome, %{
        first_name: "Valid Name",
        last_name: "Valid Last"
      })

      # This should also work for now
      {:ok, _dome} = SelectoDome.update(dome, actor.actor_id, %{
        first_name: "Updated Name"
      })
    end

    test "handles non-existent record updates", %{selecto: selecto} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Try to update a non-existent actor
      {:ok, dome} = SelectoDome.update(dome, 99999, %{first_name: "Ghost"})

      # The operation should be tracked, but will fail on commit
      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 1

      # Commit should handle the error gracefully
      result = SelectoDome.commit(dome)
      # Note: The current implementation may not have sophisticated error handling yet
      # but this tests the basic flow
    end
  end

  describe "SelectoDome change tracking" do
    setup do
      {:ok, actor} = %Actor{first_name: "Track", last_name: "Changes"} |> Repo.insert()

      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      %{dome: dome, actor: actor}
    end

    test "tracks changes correctly", %{dome: dome, actor: actor} do
      refute SelectoDome.has_changes?(dome)

      # Add an insert
      {:ok, dome} = SelectoDome.insert(dome, %{first_name: "New", last_name: "Actor"})
      assert SelectoDome.has_changes?(dome)

      # Add an update
      {:ok, dome} = SelectoDome.update(dome, actor.actor_id, %{first_name: "Updated"})
      
      # Add a delete
      {:ok, dome} = SelectoDome.delete(dome, actor.actor_id)

      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 2  # Update was overwritten by delete for same ID
      assert length(changes.inserts) == 1
      assert length(changes.updates) == 0  # Overwritten by delete
      assert length(changes.deletes) == 1
    end

    test "overwrites changes for same record ID", %{dome: dome, actor: actor} do
      # Multiple updates to the same record should result in only the latest change
      {:ok, dome} = SelectoDome.update(dome, actor.actor_id, %{first_name: "First Update"})
      {:ok, dome} = SelectoDome.update(dome, actor.actor_id, %{first_name: "Second Update"})
      {:ok, dome} = SelectoDome.update(dome, actor.actor_id, %{first_name: "Final Update"})

      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 1
      assert length(changes.updates) == 1

      update_change = hd(changes.updates)
      assert update_change.data.first_name == "Final Update"
    end

    test "delete overwrites previous changes for same record", %{dome: dome, actor: actor} do
      # Update then delete should result in only delete
      {:ok, dome} = SelectoDome.update(dome, actor.actor_id, %{first_name: "Will Be Deleted"})
      {:ok, dome} = SelectoDome.delete(dome, actor.actor_id)

      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 1
      assert length(changes.updates) == 0
      assert length(changes.deletes) == 1
    end
  end
end