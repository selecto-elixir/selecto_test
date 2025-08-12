defmodule SelectoDomeSimpleTest do
  use SelectoTest.DataCase
  
  alias SelectoTest.{Repo, PagilaDomain}
  alias SelectoTest.Store.{Actor, Language}
  alias SelectoDome

  @moduletag timeout: 10_000

  describe "SelectoDome basic operations" do
    test "basic insert operation works" do
      # Create a simple actor domain
      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])

      # Execute query
      {:ok, result} = Selecto.execute(selecto)
      
      # Create dome
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)
      
      # Verify dome was created
      assert dome.selecto == selecto
      assert dome.repo == Repo
      refute SelectoDome.has_changes?(dome)

      # Insert a new actor
      {:ok, dome} = SelectoDome.insert(dome, %{
        first_name: "Test",
        last_name: "Actor"
      })

      # Verify change is tracked
      assert SelectoDome.has_changes?(dome)
      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 1
      assert length(changes.inserts) == 1

      # Commit the change
      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify actor was created in database
      test_actor = Repo.get_by(Actor, first_name: "Test", last_name: "Actor")
      assert test_actor != nil
      assert test_actor.first_name == "Test"
      assert test_actor.last_name == "Actor"
    end

    test "basic update operation works" do
      # Create test data
      {:ok, actor} = %Actor{first_name: "Update", last_name: "Test"} |> Repo.insert()

      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Update the actor
      {:ok, dome} = SelectoDome.update(dome, actor.actor_id, %{
        first_name: "Updated"
      })

      # Verify and commit
      assert SelectoDome.has_changes?(dome)
      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify update in database
      updated_actor = Repo.get(Actor, actor.actor_id)
      assert updated_actor.first_name == "Updated"
      assert updated_actor.last_name == "Test"  # Unchanged
    end

    test "basic delete operation works" do
      # Create test data
      {:ok, actor} = %Actor{first_name: "Delete", last_name: "Test"} |> Repo.insert()

      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Delete the actor
      {:ok, dome} = SelectoDome.delete(dome, actor.actor_id)

      # Verify and commit
      assert SelectoDome.has_changes?(dome)
      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify deletion in database
      deleted_actor = Repo.get(Actor, actor.actor_id)
      assert deleted_actor == nil
    end

    test "multiple operations work together" do
      {:ok, actor1} = %Actor{first_name: "Multi1", last_name: "Test"} |> Repo.insert()
      {:ok, actor2} = %Actor{first_name: "Multi2", last_name: "Test"} |> Repo.insert()

      domain = PagilaDomain.actors_domain()
      selecto = Selecto.configure(domain, Repo)
      |> Selecto.select(["first_name", "last_name", "actor_id"])

      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

      # Perform multiple operations
      {:ok, dome} = SelectoDome.insert(dome, %{first_name: "New", last_name: "Actor"})
      {:ok, dome} = SelectoDome.update(dome, actor1.actor_id, %{first_name: "Updated1"})
      {:ok, dome} = SelectoDome.delete(dome, actor2.actor_id)

      # Verify all changes are tracked
      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 3
      assert length(changes.inserts) == 1
      assert length(changes.updates) == 1
      assert length(changes.deletes) == 1

      # Commit all changes
      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify all changes in database
      new_actor = Repo.get_by(Actor, first_name: "New", last_name: "Actor")
      updated_actor1 = Repo.get(Actor, actor1.actor_id)
      deleted_actor2 = Repo.get(Actor, actor2.actor_id)

      assert new_actor != nil
      assert updated_actor1.first_name == "Updated1"
      assert deleted_actor2 == nil
    end
  end
end