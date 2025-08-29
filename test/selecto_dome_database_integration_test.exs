defmodule SelectoDomeDatabaseIntegrationTest do
  use SelectoTest.SelectoCase, async: false

  alias SelectoDome

  @moduletag timeout: 10_000

  # This test file demonstrates SelectoDome working with real database operations
  # by using direct Postgrex connections instead of Ecto Sandbox, which avoids
  # the connection pool issues that occur when mixing Selecto with Ecto Sandbox.

  setup do
    # Create direct Postgrex connection
    postgrex_opts = [
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      database: "selecto_test_dev",
      port: 5432,
      pool_size: 1,
      pool_timeout: 5000,
      timeout: 5000
    ]

    {:ok, db_conn} = Postgrex.start_link(postgrex_opts)

    on_exit(fn ->
      if Process.alive?(db_conn) do
        GenServer.stop(db_conn, :normal, 1000)
      end
    end)

    %{db_conn: db_conn}
  end

  test "complete SelectoDome workflow with database operations", %{db_conn: db_conn} do

    # Create domain for actor table
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
    |> Selecto.select(["first_name", "last_name", "actor_id"])
    |> Selecto.filter({"actor_id", {"<", 5}})  # First 4 actors

    {:ok, {rows, columns, aliases}} = Selecto.execute(selecto)

    assert is_list(rows)
    assert length(rows) > 0
    assert "first_name" in columns
    assert "last_name" in columns
    assert "actor_id" in columns


    {:ok, dome} = SelectoDome.from_result(selecto, {rows, columns, aliases}, db_conn)

    assert dome.selecto == selecto
    assert dome.result_metadata.source_table == "actor"
    refute SelectoDome.has_changes?(dome)


    # Add insert
    {:ok, dome} = SelectoDome.insert(dome, %{
      first_name: "Test",
      last_name: "Actor"
    })

    # Add update
    {:ok, dome} = SelectoDome.update(dome, 1, %{first_name: "Updated"})

    # Add delete
    {:ok, dome} = SelectoDome.delete(dome, 2)

    assert SelectoDome.has_changes?(dome)

    {:ok, changes} = SelectoDome.preview_changes(dome)

    assert changes.total_changes == 3
    assert length(changes.inserts) == 1
    assert length(changes.updates) == 1
    assert length(changes.deletes) == 1


    insert_change = hd(changes.inserts)
    update_change = hd(changes.updates)
    delete_change = hd(changes.deletes)

    assert insert_change.type == :insert
    assert insert_change.table == "actor"
    assert insert_change.data.first_name == "Test"
    assert insert_change.data.last_name == "Actor"

    assert update_change.type == :update
    assert update_change.table == "actor"
    assert update_change.id == 1
    assert update_change.data.first_name == "Updated"

    assert delete_change.type == :delete
    assert delete_change.table == "actor"
    assert delete_change.id == 2


    metadata = SelectoDome.metadata(dome)

    assert metadata.source_table == "actor"
    assert is_map(metadata.tables)
    assert is_map(metadata.column_mapping)
    assert is_list(metadata.constraints)
    assert is_map(metadata.result_structure)

    assert is_list(metadata.result_structure.columns)
    assert is_map(metadata.result_structure.aliases)
    assert is_integer(metadata.result_structure.row_count)
    assert metadata.result_structure.row_count > 0


  end

  test "SelectoDome handles query metadata correctly", %{db_conn: db_conn} do
    # Test metadata extraction with different query structures

    domain = %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :string}
        },
        associations: %{}
      },
      name: "Film",
      joins: %{},
      schemas: %{}
    }

    selecto = Selecto.configure(domain, db_conn)
    |> Selecto.select(["title"])
    |> Selecto.filter({"film_id", {"<", 3}})

    {:ok, result} = Selecto.execute(selecto)
    {:ok, dome} = SelectoDome.from_result(selecto, result, db_conn)

    # Test that metadata is correctly extracted
    metadata = SelectoDome.metadata(dome)

    assert metadata.source_table == "film"
    assert Map.has_key?(metadata.tables, "film")

    film_table = metadata.tables["film"]
    assert film_table.table_name == "film"
    assert film_table.primary_key == "film_id"
    assert is_map(film_table.columns)

  end

  test "SelectoDome change tracking with complex scenarios", %{db_conn: db_conn} do
    # Test change tracking edge cases

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
    |> Selecto.select(["first_name", "actor_id"])
    |> Selecto.filter({"actor_id", {"<", 4}})

    {:ok, result} = Selecto.execute(selecto)
    {:ok, dome} = SelectoDome.from_result(selecto, result, db_conn)

    # Test change overwriting scenarios
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
