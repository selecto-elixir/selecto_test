defmodule SelectoDomeNoSandboxTest do
  use ExUnit.Case, async: false

  alias SelectoDome

  @moduletag timeout: 5_000

  # This test bypasses the Ecto Sandbox entirely to test if that's the issue
  test "SelectoDome works with direct Postgrex connection (no Ecto Sandbox)" do
    # Create direct Postgrex connection like our debug test
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
    
    try do
      # Create simple domain
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

      # Build a very simple Selecto query with direct connection
      selecto = Selecto.configure(domain, db_conn)
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"actor_id", {"<", 3}})  # Just first 2 actors

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
    after
      # Clean up connection
      if Process.alive?(db_conn) do
        GenServer.stop(db_conn, :normal, 1000)
      end
    end
  end
end