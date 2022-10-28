defmodule SelectoTestt.Repo.Migrations.CreatePlanets do
  use Ecto.Migration

  def change do
    create table(:planets) do
      add :name, :string
      add :mass, :float
      add :radius, :float
      add :surface_temp, :float
      add :atmosphere, :boolean, default: false, null: false
      add :solar_system_id, references(:solar_systems, on_delete: :nothing)

      timestamps()
    end

    create index(:planets, [:solar_system_id])
  end
end
