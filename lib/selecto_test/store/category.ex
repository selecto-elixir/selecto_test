defmodule SelectoTest.Store.Category do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:category_id, :id, autogenerate: true}

  schema "category" do
    field :name, :string
  end

end
