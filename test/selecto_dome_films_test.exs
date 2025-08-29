defmodule SelectoDomeFilmsTest do
  use SelectoTest.SelectoCase, async: false
  
  alias SelectoTest.{Repo, PagilaDomainFilms}
  alias SelectoTest.Store.{Film, Language}
  alias SelectoDome

  describe "SelectoDome with Pagila Film domain" do
    setup do
    # Insert test data
    _test_data = insert_test_data!()
      # Create test languages
      {:ok, english} = %Language{name: "English"} |> Repo.insert()
      {:ok, spanish} = %Language{name: "Spanish"} |> Repo.insert()
      {:ok, french} = %Language{name: "French"} |> Repo.insert()

      # Create test films
      {:ok, film1} = 
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

      {:ok, film2} = 
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

      # Set up Selecto with Film domain
      domain = PagilaDomainFilms.domain()
      selecto = Selecto.configure(domain, SelectoTest.Repo)
      |> Selecto.select(["title", "rating", "release_year", "rental_rate"])

      %{
        selecto: selecto,
        domain: domain,
        film1: film1,
        film2: film2,
        english: english,
        spanish: spanish,
        french: french
      }
    end

    test "creates dome from Film query result", %{selecto: selecto} do
      {:ok, result} = Selecto.execute(selecto)
      {rows, columns, _aliases} = result
      
      assert length(rows) >= 2  # At least our test films
      assert "title" in columns
      assert "rating" in columns
      assert "release_year" in columns

      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)
      
      assert dome.selecto == selecto
      assert dome.repo == Repo
      assert dome.result_metadata.source_table == "film"
      refute SelectoDome.has_changes?(dome)
    end

    test "inserts new film with proper data types", %{selecto: selecto, english: english} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Insert a new film with various data types
      new_film_attrs = %{
        title: "Comedy Central",
        description: "A hilarious comedy",
        release_year: 2024,
        language_id: english.language_id,
        rental_duration: 4,
        rental_rate: Decimal.new("5.99"),
        length: 95,
        replacement_cost: Decimal.new("22.99"),
        rating: :R,
        special_features: ["Deleted Scenes", "Trailers", "Commentaries"]
      }

      {:ok, dome_with_insert} = SelectoDome.insert(dome, new_film_attrs)
      assert SelectoDome.has_changes?(dome_with_insert)

      # Verify the insert details
      {:ok, changes} = SelectoDome.preview_changes(dome_with_insert)
      insert_change = hd(changes.inserts)
      assert insert_change.data.title == "Comedy Central"
      assert insert_change.data.rating == :R
      assert insert_change.data.rental_rate == Decimal.new("5.99")
      assert insert_change.data.special_features == ["Deleted Scenes", "Trailers", "Commentaries"]
    end

    test "commits film insert with complex data types", %{selecto: selecto, french: french} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      initial_count = length(elem(result, 0))

      # Insert film with array and decimal types
      {:ok, dome_with_insert} = SelectoDome.insert(dome, %{
        title: "Le Film Français",
        description: "Un film en français",
        release_year: 2024,
        language_id: french.language_id,
        rental_duration: 7,
        rental_rate: Decimal.new("6.50"),
        length: 105,
        replacement_cost: Decimal.new("29.99"),
        rating: :"NC-17",
        special_features: ["Director's Commentary", "Making Of"]
      })

      {:ok, updated_result} = SelectoDome.commit(dome_with_insert)
      {updated_rows, _columns, _aliases} = updated_result

      # Verify the film appears in result
      assert length(updated_rows) == initial_count + 1

      # Verify film exists in database with correct types
      french_film = Repo.get_by(Film, title: "Le Film Français")
      assert french_film != nil
      assert french_film.language_id == french.language_id
      assert Decimal.equal?(french_film.rental_rate, Decimal.new("6.50"))
      assert Decimal.equal?(french_film.replacement_cost, Decimal.new("29.99"))
      assert french_film.rating == :"NC-17"
      assert french_film.special_features == ["Director's Commentary", "Making Of"]
    end

    test "updates film with decimal and array fields", %{selecto: selecto, film1: film1} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Update with different data types
      update_attrs = %{
        rental_rate: Decimal.new("7.99"),
        special_features: ["Updated Trailers", "New Commentary", "Bloopers"],
        length: 135
      }

      {:ok, dome_with_update} = SelectoDome.update(dome, film1.film_id, update_attrs)
      {:ok, _updated_result} = SelectoDome.commit(dome_with_update)

      # Verify update in database
      updated_film = Repo.get(Film, film1.film_id)
      assert Decimal.equal?(updated_film.rental_rate, Decimal.new("7.99"))
      assert updated_film.special_features == ["Updated Trailers", "New Commentary", "Bloopers"]
      assert updated_film.length == 135
      # Other fields should remain unchanged
      assert updated_film.title == film1.title
      assert updated_film.rating == film1.rating
    end

    test "handles film rating enum properly", %{selecto: selecto, film2: film2} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Test each rating value
      for rating <- [:G, :PG, :"PG-13", :R, :"NC-17"] do
        {:ok, dome_with_update} = SelectoDome.update(dome, film2.film_id, %{rating: rating})
        {:ok, _updated_result} = SelectoDome.commit(dome_with_update)

        updated_film = Repo.get(Film, film2.film_id)
        assert updated_film.rating == rating
      end
    end

    test "performs batch operations on films", %{selecto: selecto, film1: film1, film2: film2, english: english} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      initial_count = length(elem(result, 0))

      # Batch operations: insert, update, delete
      {:ok, dome} = SelectoDome.insert(dome, %{
        title: "New Blockbuster",
        description: "The next big hit",
        release_year: 2024,
        language_id: english.language_id,
        rental_duration: 3,
        rental_rate: Decimal.new("4.99"),
        length: 140,
        replacement_cost: Decimal.new("25.99"),
        rating: :PG,
        special_features: ["Trailers"]
      })

      {:ok, dome} = SelectoDome.update(dome, film1.film_id, %{
        title: "Updated Action Hero",
        rental_rate: Decimal.new("5.99")
      })

      {:ok, dome} = SelectoDome.delete(dome, film2.film_id)

      # Preview all changes
      {:ok, changes} = SelectoDome.preview_changes(dome)
      assert changes.total_changes == 3
      assert length(changes.inserts) == 1
      assert length(changes.updates) == 1
      assert length(changes.deletes) == 1

      # Commit all changes
      {:ok, updated_result} = SelectoDome.commit(dome)
      {updated_rows, _columns, _aliases} = updated_result

      # Net change: +1 insert, -1 delete = same count
      assert length(updated_rows) == initial_count

      # Verify individual changes in database
      new_film = Repo.get_by(Film, title: "New Blockbuster")
      updated_film1 = Repo.get(Film, film1.film_id)
      deleted_film2 = Repo.get(Film, film2.film_id)

      assert new_film != nil
      assert updated_film1.title == "Updated Action Hero"
      assert Decimal.equal?(updated_film1.rental_rate, Decimal.new("5.99"))
      assert deleted_film2 == nil
    end
  end

  describe "SelectoDome with Film domain and Language joins" do
    setup do
    # Insert test data
    _test_data = insert_test_data!()
      {:ok, english} = %Language{name: "English"} |> Repo.insert()
      {:ok, spanish} = %Language{name: "Spanish"} |> Repo.insert()

      {:ok, film} = %Film{
        title: "International Film",
        description: "A film with language info",
        release_year: 2023,
        language_id: english.language_id,
        rental_duration: 4,
        rental_rate: Decimal.new("4.99"),
        length: 110,
        replacement_cost: Decimal.new("20.99"),
        rating: :PG,
        special_features: ["Subtitles"]
      } |> Repo.insert()

      # Create query with language join
      domain = PagilaDomainFilms.domain()
      selecto = Selecto.configure(domain, SelectoTest.Repo)
      |> Selecto.select(["title", "rating", "language_id"])

      %{
        selecto: selecto,
        film: film,
        english: english,
        spanish: spanish
      }
    end

    test "analyzes query with language dimension join", %{selecto: selecto} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      metadata = SelectoDome.metadata(dome)
      assert metadata.source_table == "film"
      
      # Should recognize the joined language table
      # Note: The exact structure depends on how QueryAnalyzer processes joins
      assert Map.has_key?(metadata.tables, "film")
    end

    test "inserts film that would appear in joined query", %{selecto: selecto, spanish: spanish} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Insert film with Spanish language
      {:ok, dome} = SelectoDome.insert(dome, %{
        title: "Película Española",
        description: "Una película en español",
        release_year: 2024,
        language_id: spanish.language_id,  # This should make it appear in the join
        rental_duration: 5,
        rental_rate: Decimal.new("3.99"),
        length: 125,
        replacement_cost: Decimal.new("21.99"),
        rating: :PG,
        special_features: ["Spanish Audio"]
      })

      {:ok, updated_result} = SelectoDome.commit(dome)

      # Verify the film appears in the joined query result
      {updated_rows, columns, _aliases} = updated_result
      
      # Find our new film in the results
      spanish_film_row = Enum.find(updated_rows, fn row ->
        title_index = Enum.find_index(columns, &(&1 == "title"))
        Enum.at(row, title_index) == "Película Española"
      end)

      assert spanish_film_row != nil

      # Verify in database
      spanish_film = Repo.get_by(Film, title: "Película Española")
      assert spanish_film != nil
      assert spanish_film.language_id == spanish.language_id
    end

    test "updates film language reference", %{selecto: selecto, film: film, spanish: spanish} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Change the film's language
      {:ok, dome} = SelectoDome.update(dome, film.film_id, %{
        language_id: spanish.language_id
      })

      {:ok, updated_result} = SelectoDome.commit(dome)

      # Verify the change is reflected in the joined result
      updated_film = Repo.get(Film, film.film_id)
      assert updated_film.language_id == spanish.language_id

      # Verify the film still appears in the joined query with the new language
      {updated_rows, columns, _aliases} = updated_result
      film_row = Enum.find(updated_rows, fn row ->
        # Assuming film_id is available in the result or we can identify by title
        title_index = Enum.find_index(columns, &(&1 == "title"))
        Enum.at(row, title_index) == "International Film"
      end)

      assert film_row != nil
    end
  end

  describe "SelectoDome data type handling" do
    setup do
    # Insert test data
    _test_data = insert_test_data!()
      {:ok, english} = %Language{name: "English"} |> Repo.insert()

      domain = PagilaDomainFilms.domain()
      selecto = Selecto.configure(domain, SelectoTest.Repo)
      |> Selecto.select(["title", "rental_rate", "replacement_cost", "special_features"])

      %{selecto: selecto, english: english}
    end

    test "handles decimal precision correctly", %{selecto: selecto, english: english} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Test precise decimal values
      precise_rates = [
        Decimal.new("0.99"),
        Decimal.new("9.99"),
        Decimal.new("99.99"),
        Decimal.new("4.50"),
        Decimal.new("12.75")
      ]

      dome = Enum.reduce(Enum.with_index(precise_rates), dome, fn {rate, index}, dome_acc ->
        {:ok, dome} = SelectoDome.insert(dome_acc, %{
          title: "Decimal Test #{index}",
          description: "Testing decimal precision",
          release_year: 2024,
          language_id: english.language_id,
          rental_duration: 3,
          rental_rate: rate,
          length: 120,
          replacement_cost: Decimal.mult(rate, 5),  # 5x the rental rate
          rating: :PG,
          special_features: []
        })
        dome
      end)

      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify decimal precision is maintained
      for {expected_rate, index} <- Enum.with_index(precise_rates) do
        film = Repo.get_by(Film, title: "Decimal Test #{index}")
        assert Decimal.equal?(film.rental_rate, expected_rate)
        assert Decimal.equal?(film.replacement_cost, Decimal.mult(expected_rate, 5))
      end
    end

    test "handles array fields correctly", %{selecto: selecto, english: english} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Test different array configurations
      test_cases = [
        [],  # Empty array
        ["Trailers"],  # Single element
        ["Trailers", "Commentaries"],  # Multiple elements
        ["Behind the Scenes", "Deleted Scenes", "Director's Commentary", "Cast Interviews"]  # Many elements
      ]

      dome = Enum.reduce(Enum.with_index(test_cases), dome, fn {features, index}, dome_acc ->
        {:ok, dome} = SelectoDome.insert(dome_acc, %{
          title: "Array Test #{index}",
          description: "Testing array handling",
          release_year: 2024,
          language_id: english.language_id,
          rental_duration: 3,
          rental_rate: Decimal.new("4.99"),
          length: 120,
          replacement_cost: Decimal.new("19.99"),
          rating: :PG,
          special_features: features
        })
        dome
      end)

      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify arrays are stored correctly
      for {expected_features, index} <- Enum.with_index(test_cases) do
        film = Repo.get_by(Film, title: "Array Test #{index}")
        assert film.special_features == expected_features
      end
    end

    test "handles enum ratings properly", %{selecto: selecto, english: english} do
      {:ok, result} = Selecto.execute(selecto)
      {:ok, dome} = SelectoDome.from_result(selecto, result, SelectoTest.Repo)

      # Test all valid ratings
      ratings = [:G, :PG, :"PG-13", :R, :"NC-17"]

      dome = Enum.reduce(ratings, dome, fn rating, dome_acc ->
        {:ok, dome} = SelectoDome.insert(dome_acc, %{
          title: "Rating Test #{rating}",
          description: "Testing rating #{rating}",
          release_year: 2024,
          language_id: english.language_id,
          rental_duration: 3,
          rental_rate: Decimal.new("4.99"),
          length: 120,
          replacement_cost: Decimal.new("19.99"),
          rating: rating,
          special_features: []
        })
        dome
      end)

      {:ok, _updated_result} = SelectoDome.commit(dome)

      # Verify all ratings were stored correctly
      for rating <- ratings do
        film = Repo.get_by(Film, title: "Rating Test #{rating}")
        assert film.rating == rating
      end
    end
  end
end