defmodule SelectoTest.Seed do
  alias SelectoTest.Repo
  alias SelectoTest.Store.{Language, Film, Flag}
  
  def init() do
    # Create flags
    Repo.insert! %Flag{name: "F1"}
    Repo.insert! %Flag{name: "F2"}
    Repo.insert! %Flag{name: "F3"}
    Repo.insert! %Flag{name: "F4"}

    # Create languages
    english = Repo.insert! %Language{name: "English"}
    _spanish = Repo.insert! %Language{name: "Spanish"}
    
    # Create films with various data types for column type testing
    Repo.insert! Film.changeset(%Film{}, %{
      title: "Academy Dinosaur",
      description: "A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies",
      release_year: 2006,
      language_id: english.language_id,
      rental_duration: 6,
      rental_rate: Decimal.new("0.99"),
      length: 86,
      replacement_cost: Decimal.new("20.99"),
      rating: :PG,
      special_features: ["Deleted Scenes", "Behind the Scenes"]
    })
    
    Repo.insert! Film.changeset(%Film{}, %{
      title: "Ace Goldfinger",
      description: "A Astounding Epistle of a Database Administrator And a Explorer who must Find a Car in Ancient China",
      release_year: 2006,
      language_id: english.language_id,
      rental_duration: 3,
      rental_rate: Decimal.new("4.99"),
      length: 48,
      replacement_cost: Decimal.new("12.99"),
      rating: :G,
      special_features: ["Trailers", "Deleted Scenes"]
    })
    
    Repo.insert! Film.changeset(%Film{}, %{
      title: "Adaptation Holes",
      description: "A Astounding Reflection of a Lumberjack And a Car who must Sink a Lumberjack in A Baloon Factory",
      release_year: 2006,
      language_id: english.language_id,
      rental_duration: 7,
      rental_rate: Decimal.new("2.99"),
      length: 50,
      replacement_cost: Decimal.new("18.99"),
      rating: :"NC-17",
      special_features: ["Trailers", "Commentaries"]
    })
  end
end
