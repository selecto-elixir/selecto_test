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
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SelectoTest.Repo, shared: true)
    
    # Clean up data before test
    cleanup_database()
    
    on_exit(fn ->
      # Clean up after test
      cleanup_database()
      # Stop Ecto sandbox
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)
    
    %{}
  end
  
  @doc """
  Clean up database tables using Ecto.
  """
  def cleanup_database do
    # Clean up in dependency order using Ecto
    cleanup_schemas = [
      SelectoTest.Store.FilmActor,
      SelectoTest.Store.FilmCategory,
      SelectoTest.Store.Film,
      SelectoTest.Store.Actor,
      SelectoTest.Store.Category,
      SelectoTest.Store.Language
    ]
    
    Enum.each(cleanup_schemas, fn schema ->
      try do
        SelectoTest.Repo.delete_all(schema)
      rescue
        Ecto.QueryError -> 
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