defmodule SelectoTest.Store.FilmCategory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "film_category" do
    # has_one category
    belongs_to :category, SelectoTest.Store.Category, primary_key: true, references: :category_id
    # has_one film
    belongs_to :film, SelectoTest.Store.Film, primary_key: true, references: :film_id
  end
end
