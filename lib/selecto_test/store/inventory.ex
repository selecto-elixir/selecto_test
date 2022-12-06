defmodule SelectoTest.Store.Inventory do
  use Ecto.Schema

  @primary_key {:inventory_id, :id, autogenerate: true}

  schema "inventory" do
    belongs_to :film, SelectoTest.Store.Film, references: :film_id
    belongs_to :store, SelectoTest.Store.Store, references: :store_id, foreign_key: :store_id
    has_many :rentals, SelectoTest.Store.Rental, foreign_key: :inventory_id, references: :inventory_id
  end
end
