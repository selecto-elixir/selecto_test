defmodule SelectoTest.Store.Inventory do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:inventory_id, :id, autogenerate: true}

  schema "inventory" do
    belongs_to :film, SelectoTest.Store.Film, references: :film_id
    belongs_to :store, SelectoTest.Store.Store, references: :store_id
  end

end
