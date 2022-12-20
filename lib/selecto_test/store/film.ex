defmodule SelectoTest.Store.Film do
  use Ecto.Schema

  @primary_key {:film_id, :id, autogenerate: true}

  schema "film" do
    field :title, :string
    field :description, :string
    field :release_year, :integer

    belongs_to :language, SelectoTest.Store.Language,
      foreign_key: :language_id,
      references: :language_id

    field :rental_duration, :integer
    field :rental_rate, :decimal
    field :length, :integer
    field :replacement_cost, :decimal

    field :last_update, :utc_datetime

    ## MPAA Rating ENum?
    field :rating, Ecto.Enum, values: [:G, :PG, :"PG-13", :R, :"NC-17"]

    field :special_features, {:array, :string}

    has_many :film_actors, SelectoTest.Store.FilmActor, foreign_key: :film_id
    has_many :actors, through: [:film_actors, :actor]

    has_many :film_category, SelectoTest.Store.FilmCategory, foreign_key: :film_id
    has_many :categories, through: [:film_category, :category]

    #field :fulltext,

  end
end
