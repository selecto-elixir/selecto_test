defmodule SelectoDomeRepoTest do
  use ExUnit.Case, async: false

  alias SelectoTest.Repo
  alias SelectoDome

  @moduletag timeout: 10_000

  setup do
    # Check out a sandbox connection for this test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  test "debug Selecto result structure using existing repo" do
    # Using the existing repository connection with proper sandbox setup
    
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

    # Use the existing repo connection
    selecto = Selecto.configure(domain, Repo)
    |> Selecto.select(["first_name"])
    |> Selecto.filter({"actor_id", 1})

    case Selecto.execute(selecto) do
      {:ok, result} ->
        {rows, columns, aliases} = result
        
        IO.puts("\n=== DEBUG WITH REPO ===")
        IO.puts("Rows: #{inspect(rows, limit: 3)}")
        IO.puts("Columns: #{inspect(columns)}")
        IO.puts("Aliases: #{inspect(aliases)}")
        IO.puts("Aliases type: #{inspect(is_map(aliases))}")
        IO.puts("Aliases is list?: #{inspect(is_list(aliases))}")
        
        # Try to create a dome
        case SelectoDome.from_result(selecto, result, Repo) do
          {:ok, dome} ->
            IO.puts("✅ SelectoDome created successfully!")
            IO.puts("Source table: #{dome.result_metadata.source_table}")
            IO.puts("Row count: #{dome.result_metadata.result_structure.row_count}")
          {:error, reason} ->
            IO.puts("❌ SelectoDome creation failed: #{inspect(reason)}")
        end
        
        IO.puts("========================\n")
        
      {:error, reason} ->
        IO.puts("❌ Selecto query failed: #{inspect(reason)}")
    end
  end

  test "test basic SelectoDome operations using existing repo" do
    # Using the existing repository connection with proper sandbox setup
    
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

    # Use the existing repo connection
    selecto = Selecto.configure(domain, Repo)
    |> Selecto.select(["first_name", "last_name", "actor_id"])
    |> Selecto.filter({"actor_id", {"<", 10}})

    {:ok, result} = Selecto.execute(selecto)
    {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)
    
    # Test basic operations without database commits
    {:ok, dome_with_insert} = SelectoDome.insert(dome, %{
      first_name: "Test",
      last_name: "Actor"
    })
    
    assert SelectoDome.has_changes?(dome_with_insert)
    
    {:ok, changes} = SelectoDome.preview_changes(dome_with_insert)
    assert changes.total_changes == 1
    assert length(changes.inserts) == 1
    
    # Test multiple changes
    {:ok, dome_multi} = SelectoDome.update(dome_with_insert, 1, %{first_name: "Updated"})
    {:ok, dome_multi} = SelectoDome.delete(dome_multi, 2)
    
    {:ok, multi_changes} = SelectoDome.preview_changes(dome_multi)
    assert multi_changes.total_changes == 3
    
    IO.puts("\n✅ All SelectoDome operations working correctly with Repo!")
    IO.puts("Total changes tracked: #{multi_changes.total_changes}")
  end
end