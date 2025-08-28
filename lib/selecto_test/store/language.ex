defmodule SelectoTest.Store.Language do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:language_id, :id, autogenerate: true}

  schema "language" do
    field :name, :string
  end

  def changeset(language, attrs) do
    language
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
