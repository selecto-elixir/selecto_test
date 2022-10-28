defmodule SelectoTest.Test.SolarSystem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "solar_systems" do
    field :galaxy, :string
    field :name, :string

    has_many :planets, SelectoTest.Test.Planet

    timestamps()
  end

  @doc false
  def changeset(solar_system, attrs) do
    solar_system
    |> cast(attrs, [:name, :galaxy])
    |> validate_required([:name, :galaxy])
  end
end
