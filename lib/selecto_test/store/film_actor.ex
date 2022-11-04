defmodule SelectoTest.Store.FilmActor do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "film_actor" do
    belongs_to :actor, SelectoTest.Store.Actor, primary_key: true, references: :actor_id
    belongs_to :film, SelectoTest.Store.Film, primary_key: true, references: :film_id
  end

end
