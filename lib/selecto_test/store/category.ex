defmodule SelectoTest.Store.Category do
  use Ecto.Schema

  @primary_key {:category_id, :id, autogenerate: true}

  schema "category" do
    field :name, :string
  end
end
