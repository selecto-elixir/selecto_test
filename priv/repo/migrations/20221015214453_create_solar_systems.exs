defmodule SelectoTestt.Repo.Migrations.CreateSolarSystems do
  use Ecto.Migration

  def change do
    create table(:solar_systems) do
      add :name, :string
      add :galaxy, :string

      timestamps()
    end
  end
end
