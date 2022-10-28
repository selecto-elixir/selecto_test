defmodule SelectoTestt.Test.Planet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "planets" do
    field :atmosphere, :boolean, default: false
    field :mass, :float
    field :name, :string
    field :radius, :float
    field :surface_temp, :float

    belongs_to :solar_system, SelectoTestt.Test.SolarSystem
    has_many :satellites, SelectoTestt.Test.Satellite

    timestamps()
  end

  @doc false
  def changeset(planet, attrs) do
    planet
    |> cast(attrs, [:name, :mass, :radius, :surface_temp, :atmosphere])
    |> validate_required([:name, :mass, :radius, :surface_temp, :atmosphere])
  end
end
