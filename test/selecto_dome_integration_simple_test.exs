defmodule SelectoDomeIntegrationSimpleTest do
  use ExUnit.Case, async: false

  alias SelectoTest.Repo
  alias SelectoDome

  @moduletag timeout: 5_000

  setup do
    # Check out a sandbox connection for this test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  test "SelectoDome integrates with Selecto using simple domain" do
    # Create a very simple domain to avoid complex query issues
    domain = %{
      source: %{
        source_table: "actor",
        primary_key: :actor_id,
        fields: [:actor_id, :first_name],
        redact_fields: [],
        columns: %{
          actor_id: %{type: :integer},
          first_name: %{type: :string}
        },
        associations: %{}
      },
      name: "SimpleActor",
      joins: %{},
      schemas: %{}
    }

    # Build a very simple Selecto query
    selecto = Selecto.configure(domain, Repo)
    |> Selecto.select(["first_name"])
    |> Selecto.filter({"actor_id", {"<", 5}})  # Limit to first few actors

    case Selecto.execute(selecto) do
      {:ok, {rows, columns, aliases}} ->
        IO.puts("\n✅ Selecto query executed successfully!")
        IO.puts("Rows: #{inspect(length(rows))}")
        IO.puts("Columns: #{inspect(columns)}")
        IO.puts("Aliases: #{inspect(is_list(aliases))}")
        
        # Test SelectoDome creation
        case SelectoDome.from_result(selecto, {rows, columns, aliases}, Repo) do
          {:ok, dome} ->
            IO.puts("✅ SelectoDome created successfully!")
            
            # Test basic operations without database commits
            {:ok, dome} = SelectoDome.insert(dome, %{first_name: "Test Actor"})
            {:ok, changes} = SelectoDome.preview_changes(dome)
            
            assert changes.total_changes == 1
            assert length(changes.inserts) == 1
            
            IO.puts("✅ SelectoDome operations work correctly!")
            
          {:error, reason} ->
            IO.puts("❌ SelectoDome creation failed: #{inspect(reason)}")
            flunk("SelectoDome creation failed")
        end
        
      {:error, reason} ->
        IO.puts("❌ Selecto query failed: #{inspect(reason)}")
        flunk("Selecto query failed: #{inspect(reason)}")
    end
  end
end