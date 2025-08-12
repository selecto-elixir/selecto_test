defmodule SelectoDomeDebugTest do
  use ExUnit.Case, async: false

  test "debug Selecto result structure" do
    # Use the existing repo connection to avoid pool issues
    repo_config = SelectoTest.Repo.config()
    postgrex_opts = [
      username: repo_config[:username],
      password: repo_config[:password],
      hostname: repo_config[:hostname], 
      database: repo_config[:database],
      port: repo_config[:port] || 5432,
      pool_size: 1,
      pool_timeout: 5000,
      timeout: 5000
    ]
    
    # Use a shorter-lived connection with immediate cleanup
    {:ok, db_conn} = Postgrex.start_link(postgrex_opts)
    
    try do
    
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

    # Configure and execute Selecto
    selecto = Selecto.configure(domain, db_conn)
    |> Selecto.select(["first_name"])
    |> Selecto.filter({"actor_id", 1})

    {:ok, result} = Selecto.execute(selecto)
    {rows, columns, aliases} = result

    # Debug the actual structure
    IO.puts("\n=== DEBUG SELECTO RESULT ===")
    IO.puts("Rows: #{inspect(rows, limit: 3)}")
    IO.puts("Columns: #{inspect(columns)}")
    IO.puts("Aliases: #{inspect(aliases)}")
    IO.puts("Aliases type: #{inspect(is_map(aliases))}")
    IO.puts("Aliases is list?: #{inspect(is_list(aliases))}")
    IO.puts("========================\n")
    
    after
      # Ensure connection is always cleaned up
      if Process.alive?(db_conn) do
        GenServer.stop(db_conn, :normal, 1000)
      end
    end
  end
end