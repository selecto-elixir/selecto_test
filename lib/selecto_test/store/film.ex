defmodule SelectoTest.Store.Film do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:film_id, :id, autogenerate: true}

  schema "film" do
    field :title, :string
    field :description, :string
    field :release_year, :integer

    #has_one language
    #has_one original_language

    field :rental_duration, :integer
    field :rental_rate, :decimal
    field :length, :integer
    field :replacement_cost, :decimal

    ## MPAA Rating ENum?

    field :special_features, {:array, :string}

    has_many :film_actors, SelectoTest.Store.FilmActor, foreign_key: :film_id
    has_many :actors, through: [:film_actors, :actor]

  end

end
