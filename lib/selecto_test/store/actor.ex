defmodule SelectoTest.Store.Actor do
  use Ecto.Schema

  @primary_key {:actor_id, :id, autogenerate: true}

  schema "actor" do
    field :first_name, :string
    field :last_name, :string

    has_many :film_actors, SelectoTest.Store.FilmActor, foreign_key: :actor_id
    has_many :films, through: [:film_actors, :film]
  end
end
