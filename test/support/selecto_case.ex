defmodule SelectoTest.SelectoCase do
  @moduledoc """
  Test case for Selecto-based tests using Ecto sandbox.
  
  This test case provides:
  - Ecto sandbox setup for test isolation
  - Database cleanup between tests 
  - Proper connection lifecycle management
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      alias SelectoTest.Repo
      
      import Ecto
      import Ecto.Query
      import SelectoTest.SelectoCase
    end
  end
  
  setup _tags do
    # Set up Ecto sandbox with shared mode for Selecto integration
    # This allows Selecto's separate connections to see test data
    # Handle case where sandbox is already shared
    {pid, started_owner?} = try do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SelectoTest.Repo, shared: true)
      {pid, true}
    rescue
      MatchError ->
        # Sandbox is already shared, just checkout a connection
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(SelectoTest.Repo)
        {nil, false}
    end
    
    # Clean up data before test
    try do
      cleanup_database()
    rescue
      e ->
        # If cleanup fails, log and continue - test data isolation might still work
        IO.warn("Database cleanup failed: #{inspect(e)}")
    end
    
    on_exit(fn ->
      # Clean up after test
      try do
        cleanup_database()
      rescue
        e ->
          # If cleanup fails, log but don't crash the test suite
          IO.warn("Database cleanup on exit failed: #{inspect(e)}")
      end
      
      # Stop Ecto sandbox if we started one, otherwise just checkin
      try do
        if started_owner? do
          Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
        else
          Ecto.Adapters.SQL.Sandbox.checkin(SelectoTest.Repo)
        end
      rescue
        e ->
          # Log sandbox cleanup errors but don't fail
          IO.warn("Sandbox cleanup failed: #{inspect(e)}")
      end
    end)
    
    %{}
  end
  
  @doc """
  Clean up database tables using Ecto in proper dependency order.
  """
  def cleanup_database do
    # Clean up in reverse dependency order (children first, then parents)
    # This ensures we don't hit foreign key constraint violations
    cleanup_schemas = [
      # Child tables first (tables that reference others)
      SelectoTest.Store.FilmActor,     # References film and actor
      SelectoTest.Store.FilmCategory,  # References film and category
      # Parent tables
      SelectoTest.Store.Film,          # May be referenced by inventory, etc.
      SelectoTest.Store.Actor,
      SelectoTest.Store.Category,
      SelectoTest.Store.Language
    ]
    
    # Also clean up additional tables that might exist in Pagila DB
    additional_cleanup = [
      "inventory",    # References film
      "rental",       # References inventory
      "payment",      # References rental
      "staff",
      "store",
      "customer",
      "address",
      "city",
      "country"
    ]
    
    # Delete from additional tables first (raw SQL for tables without schemas)
    Enum.each(additional_cleanup, fn table ->
      try do
        SelectoTest.Repo.query("DELETE FROM #{table}", [])
      rescue
        _ -> 
          # Table doesn't exist or other error, that's fine for tests
          :ok
      end
    end)
    
    # Then delete from schema-backed tables
    Enum.each(cleanup_schemas, fn schema ->
      try do
        SelectoTest.Repo.delete_all(schema)
      rescue
        _ -> 
          # Table doesn't exist or other error, that's fine for tests
          :ok
      end
    end)
  end
  
  @doc """
  Insert test data using Ecto.
  """
  def insert_test_data! do
    # Basic test data
    {:ok, english} = %SelectoTest.Store.Language{name: "English"} |> SelectoTest.Repo.insert()
    {:ok, spanish} = %SelectoTest.Store.Language{name: "Spanish"} |> SelectoTest.Repo.insert()
    
    {:ok, actor1} = %SelectoTest.Store.Actor{first_name: "John", last_name: "Doe"} |> SelectoTest.Repo.insert()
    {:ok, actor2} = %SelectoTest.Store.Actor{first_name: "Jane", last_name: "Smith"} |> SelectoTest.Repo.insert() 
    {:ok, actor3} = %SelectoTest.Store.Actor{first_name: "Bob", last_name: "Wilson"} |> SelectoTest.Repo.insert()
    {:ok, actor4} = %SelectoTest.Store.Actor{first_name: "Alice", last_name: "Johnson"} |> SelectoTest.Repo.insert()
    
    {:ok, film1} = %SelectoTest.Store.Film{
      title: "Test Film 1",
      description: "A test film",
      release_year: 2023,
      language_id: english.language_id,
      rental_duration: 3,
      rental_rate: Decimal.new("4.99"),
      length: 120,
      replacement_cost: Decimal.new("19.99"),
      rating: :PG
    } |> SelectoTest.Repo.insert()
    
    {:ok, film2} = %SelectoTest.Store.Film{
      title: "Test Film 2", 
      description: "Another test film",
      release_year: 2024,
      language_id: spanish.language_id,
      rental_duration: 5,
      rental_rate: Decimal.new("3.99"),
      length: 150,
      replacement_cost: Decimal.new("24.99"),
      rating: :PG
    } |> SelectoTest.Repo.insert()
    
    %{
      languages: %{english: english, spanish: spanish},
      actors: %{actor1: actor1, actor2: actor2, actor3: actor3, actor4: actor4},
      films: %{film1: film1, film2: film2}
    }
  end
end