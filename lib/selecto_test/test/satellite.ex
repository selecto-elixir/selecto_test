defmodule SelectoTestt.Test.Satellite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "satellites" do
    field :mass, :float
    field :name, :string
    field :period, :float
    field :radius, :float

    belongs_to :planet, SelectoTestt.Test.Planet

    timestamps()
  end

  @doc false
  def changeset(satellite, attrs) do
    satellite
    |> cast(attrs, [:name, :period, :mass, :radius])
    |> validate_required([:name, :period, :mass, :radius])
  end
end
