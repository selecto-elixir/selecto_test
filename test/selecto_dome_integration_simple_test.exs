defmodule SelectoDomeIntegrationSimpleTest do
  use SelectoTest.SelectoCase, async: false

  alias SelectoTest.Repo
  alias SelectoDome

  @moduletag timeout: 5_000

  test "SelectoDome integrates with Selecto using simple domain" do
    # Insert test data
    _test_data = insert_test_data!()
    
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
    selecto = Selecto.configure(domain, SelectoTest.Repo)
    |> Selecto.select(["first_name"])
    |> Selecto.filter({"actor_id", {"<", 5}})  # Limit to first few actors

    case Selecto.execute(selecto) do
      {:ok, {rows, columns, aliases}} ->
        # Test SelectoDome creation
        case SelectoDome.from_result(selecto, {rows, columns, aliases}, SelectoTest.Repo) do
          {:ok, dome} ->
            # Test basic operations without database commits
            {:ok, dome} = SelectoDome.insert(dome, %{first_name: "Test Actor"})
            {:ok, changes} = SelectoDome.preview_changes(dome)
            
            assert changes.total_changes == 1
            assert length(changes.inserts) == 1
            
          {:error, reason} ->
            flunk("SelectoDome creation failed")
        end
        
      {:error, reason} ->
        flunk("Selecto query failed: #{inspect(reason)}")
    end
  end
end