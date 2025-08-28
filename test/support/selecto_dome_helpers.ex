defmodule SelectoTest.SelectoDomeHelpers do
  @moduledoc """
  Helper functions for testing SelectoDome functionality.
  
  This module provides utilities for setting up test scenarios,
  creating test data, and verifying SelectoDome operations.
  """

  alias SelectoTest.{Repo, PagilaDomain, PagilaDomainFilms}
  alias SelectoTest.Store.{Actor, Film, Language, FilmActor}
  alias SelectoDome

  @doc """
  Create a basic actor dataset for testing.
  
  Returns a map with created actors and a configured Selecto.
  """
  def setup_actor_test_data do
    # Clean slate
    Repo.delete_all(FilmActor)
    Repo.delete_all(Actor)
    Repo.delete_all(Film)
    Repo.delete_all(Language)

    # Create test data
    {:ok, english} = %Language{name: "English"} |> Repo.insert()
    
    {:ok, john} = %Actor{first_name: "John", last_name: "Doe"} |> Repo.insert()
    {:ok, jane} = %Actor{first_name: "Jane", last_name: "Smith"} |> Repo.insert()
    {:ok, bob} = %Actor{first_name: "Bob", last_name: "Wilson"} |> Repo.insert()

    {:ok, action_film} = %Film{
      title: "Action Movie",
      description: "An action-packed film",
      release_year: 2023,
      language_id: english.language_id,
      rental_duration: 3,
      rental_rate: Decimal.new("4.99"),
      length: 120,
      replacement_cost: Decimal.new("19.99"),
      rating: :PG
    } |> Repo.insert()

    # Create some film-actor relationships
    {:ok, _} = %FilmActor{film_id: action_film.film_id, actor_id: john.actor_id} |> Repo.insert()
    {:ok, _} = %FilmActor{film_id: action_film.film_id, actor_id: jane.actor_id} |> Repo.insert()

    # Configure Selecto
    domain = PagilaDomain.actors_domain()
    selecto = Selecto.configure(domain, Repo)
    |> Selecto.select(["first_name", "last_name", "actor_id"])

    %{
      actors: %{john: john, jane: jane, bob: bob},
      films: %{action: action_film},
      languages: %{english: english},
      selecto: selecto
    }
  end

  @doc """
  Create a basic film dataset for testing.
  
  Returns a map with created films and a configured Selecto.
  """
  def setup_film_test_data do
    # Clean slate
    Repo.delete_all(FilmActor)
    Repo.delete_all(Film)
    Repo.delete_all(Language)

    # Create languages
    {:ok, english} = %Language{name: "English"} |> Repo.insert()
    {:ok, spanish} = %Language{name: "Spanish"} |> Repo.insert()
    {:ok, french} = %Language{name: "French"} |> Repo.insert()

    # Create films
    {:ok, action_film} = 
      Film.changeset(%Film{}, %{
        title: "Action Hero",
        description: "An action-packed adventure",
        release_year: 2023,
        language_id: english.language_id,
        rental_duration: 3,
        rental_rate: Decimal.new("4.99"),
        length: 120,
        replacement_cost: Decimal.new("19.99"),
        rating: :PG,
        special_features: ["Trailers", "Commentaries"]
      }) |> Repo.insert()

    {:ok, drama_film} = 
      Film.changeset(%Film{}, %{
        title: "Drama Queen",
        description: "A dramatic story",
        release_year: 2022,
        language_id: spanish.language_id,
        rental_duration: 5,
        rental_rate: Decimal.new("3.99"),
        length: 150,
        replacement_cost: Decimal.new("24.99"),
        rating: :"PG-13",
        special_features: ["Behind the Scenes"]
      }) |> Repo.insert()

    # Configure Selecto
    domain = PagilaDomainFilms.domain()
    selecto = Selecto.configure(domain, Repo)
    |> Selecto.select(["title", "rating", "release_year", "rental_rate"])

    %{
      films: %{action: action_film, drama: drama_film},
      languages: %{english: english, spanish: spanish, french: french},
      selecto: selecto
    }
  end

  @doc """
  Execute a Selecto query and create a SelectoDome.
  
  Returns `{:ok, dome, result}` or `{:error, reason}`.
  """
  def execute_and_create_dome(selecto) do
    case Selecto.execute(selecto) do
      {:ok, result} ->
        case SelectoDome.from_result(selecto, result, Repo) do
          {:ok, dome} -> {:ok, dome, result}
          {:error, reason} -> {:error, {:dome_creation_failed, reason}}
        end
      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  end

  @doc """
  Perform a complete insert-and-commit cycle.
  
  Helper for testing the full flow of inserting data through SelectoDome.
  """
  def insert_and_commit(dome, attrs) do
    with {:ok, dome_with_insert} <- SelectoDome.insert(dome, attrs),
         {:ok, updated_result} <- SelectoDome.commit(dome_with_insert) do
      {:ok, dome_with_insert, updated_result}
    end
  end

  @doc """
  Perform a complete update-and-commit cycle.
  
  Helper for testing the full flow of updating data through SelectoDome.
  """
  def update_and_commit(dome, record_id, attrs) do
    with {:ok, dome_with_update} <- SelectoDome.update(dome, record_id, attrs),
         {:ok, updated_result} <- SelectoDome.commit(dome_with_update) do
      {:ok, dome_with_update, updated_result}
    end
  end

  @doc """
  Perform a complete delete-and-commit cycle.
  
  Helper for testing the full flow of deleting data through SelectoDome.
  """
  def delete_and_commit(dome, record_id) do
    with {:ok, dome_with_delete} <- SelectoDome.delete(dome, record_id),
         {:ok, updated_result} <- SelectoDome.commit(dome_with_delete) do
      {:ok, dome_with_delete, updated_result}
    end
  end

  @doc """
  Verify that a record exists in the database with the expected attributes.
  """
  def assert_record_exists(schema, expected_attrs) do
    record = Repo.get_by(schema, expected_attrs)
    if record == nil do
      raise "Expected record with attributes #{inspect(expected_attrs)} not found in #{schema}"
    end
    record
  end

  @doc """
  Verify that a record does not exist in the database.
  """
  def assert_record_not_exists(schema, search_attrs) do
    record = Repo.get_by(schema, search_attrs)
    if record != nil do
      raise "Expected record with attributes #{inspect(search_attrs)} to not exist, but found #{inspect(record)}"
    end
  end

  @doc """
  Create a dome with multiple pending changes for testing batch operations.
  """
  def create_dome_with_multiple_changes(selecto, changes_spec) do
    {:ok, result} = Selecto.execute(selecto)
    {:ok, dome} = SelectoDome.from_result(selecto, result, Repo)

    Enum.reduce(changes_spec, dome, fn change, acc_dome ->
      case change do
        {:insert, attrs} ->
          {:ok, updated_dome} = SelectoDome.insert(acc_dome, attrs)
          updated_dome

        {:update, record_id, attrs} ->
          {:ok, updated_dome} = SelectoDome.update(acc_dome, record_id, attrs)
          updated_dome

        {:delete, record_id} ->
          {:ok, updated_dome} = SelectoDome.delete(acc_dome, record_id)
          updated_dome
      end
    end)
  end

  @doc """
  Verify that a SelectoDome result contains the expected number of rows.
  """
  def assert_result_row_count({rows, _columns, _aliases}, expected_count) do
    actual_count = length(rows)
    if actual_count != expected_count do
      raise "Expected #{expected_count} rows in result, got #{actual_count}"
    end
  end

  @doc """
  Find a row in the query result by a specific column value.
  """
  def find_row_by_column_value({rows, columns, _aliases}, column_name, expected_value) do
    column_index = Enum.find_index(columns, &(&1 == column_name))
    if column_index == nil do
      raise "Column '#{column_name}' not found in result columns: #{inspect(columns)}"
    end

    Enum.find(rows, fn row ->
      Enum.at(row, column_index) == expected_value
    end)
  end

  @doc """
  Extract a specific column value from a result row.
  """
  def get_column_value_from_row(row, columns, column_name) when is_list(row) and is_list(columns) do
    column_index = Enum.find_index(columns, &(&1 == column_name))
    if column_index == nil do
      raise "Column '#{column_name}' not found in columns: #{inspect(columns)}"
    end

    Enum.at(row, column_index)
  end

  @doc """
  Create test data for join scenarios.
  """
  def setup_join_test_data do
    # Clean slate
    Repo.delete_all(FilmActor)
    Repo.delete_all(Actor)
    Repo.delete_all(Film)
    Repo.delete_all(Language)

    # Create languages
    {:ok, english} = %Language{name: "English"} |> Repo.insert()
    {:ok, spanish} = %Language{name: "Spanish"} |> Repo.insert()

    # Create actors
    {:ok, tom} = %Actor{first_name: "Tom", last_name: "Hanks"} |> Repo.insert()
    {:ok, meryl} = %Actor{first_name: "Meryl", last_name: "Streep"} |> Repo.insert()

    # Create films
    {:ok, drama} = %Film{
      title: "Great Drama",
      description: "A masterpiece",
      release_year: 2023,
      language_id: english.language_id,
      rental_duration: 5,
      rental_rate: Decimal.new("5.99"),
      length: 180,
      replacement_cost: Decimal.new("29.99"),
      rating: :R
    } |> Repo.insert()

    {:ok, comedy} = %Film{
      title: "Funny Comedy",
      description: "Hilarious fun",
      release_year: 2022,
      language_id: spanish.language_id,
      rental_duration: 3,
      rental_rate: Decimal.new("3.99"),
      length: 95,
      replacement_cost: Decimal.new("19.99"),
      rating: :PG
    } |> Repo.insert()

    # Create film-actor relationships
    {:ok, _} = %FilmActor{film_id: drama.film_id, actor_id: tom.actor_id} |> Repo.insert()
    {:ok, _} = %FilmActor{film_id: drama.film_id, actor_id: meryl.actor_id} |> Repo.insert()
    {:ok, _} = %FilmActor{film_id: comedy.film_id, actor_id: tom.actor_id} |> Repo.insert()

    %{
      actors: %{tom: tom, meryl: meryl},
      films: %{drama: drama, comedy: comedy},
      languages: %{english: english, spanish: spanish}
    }
  end

  @doc """
  Validate that all changes in a change summary are of expected types.
  """
  def validate_change_summary(changes, expected_counts) do
    actual_counts = %{
      inserts: length(changes.inserts),
      updates: length(changes.updates),
      deletes: length(changes.deletes),
      total: changes.total_changes
    }

    Enum.each(expected_counts, fn {type, expected_count} ->
      actual_count = Map.get(actual_counts, type, 0)
      if actual_count != expected_count do
        raise "Expected #{expected_count} #{type}, got #{actual_count}. Full summary: #{inspect(actual_counts)}"
      end
    end)

    changes
  end

  @doc """
  Measure the execution time of a SelectoDome operation.
  """
  def time_operation(operation_fn) do
    start_time = System.monotonic_time(:millisecond)
    result = operation_fn.()
    end_time = System.monotonic_time(:millisecond)
    
    duration = end_time - start_time
    {result, duration}
  end
end