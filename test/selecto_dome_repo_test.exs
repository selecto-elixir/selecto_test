defmodule SelectoDomeRepoTest do
  use SelectoTest.SelectoCase, async: false

  # alias SelectoTest.Repo  # Unused
  alias SelectoDome

  @moduletag timeout: 10_000

  test "debug Selecto result structure using existing repo" do
    # Insert test data
    _test_data = insert_test_data!()
    
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
    selecto = Selecto.configure(domain, SelectoTest.Repo)
    |> Selecto.select(["first_name"])
    |> Selecto.filter({"actor_id", 1})

    case Selecto.execute(selecto) do
      {:ok, result} ->
        {_rows, _columns, _aliases} = result
        
        # Try to create a dome - should succeed
        case SelectoDome.from_result(selecto, result, SelectoTest.Repo) do
          {:ok, _dome} ->
            :ok
          {:error, reason} ->
            flunk("SelectoDome creation failed: #{inspect(reason)}")
        end
        
      {:error, reason} ->
        flunk("Selecto query failed: #{inspect(reason)}")
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
    selecto = Selecto.configure(domain, SelectoTest.Repo)
    |> Selecto.select(["first_name", "last_name", "actor_id"])
    |> Selecto.filter({"actor_id", {"<", 10}})

    {:ok, result} = Selecto.execute(selecto)
    {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)
    
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
    
  end
end