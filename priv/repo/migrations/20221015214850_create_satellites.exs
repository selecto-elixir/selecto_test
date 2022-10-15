defmodule ListableTest.Repo.Migrations.CreateSatellites do
  use Ecto.Migration

  def change do
    create table(:satellites) do
      add :name, :string
      add :period, :float
      add :mass, :float
      add :radius, :float
      add :planet_id, references(:planets, on_delete: :nothing)

      timestamps()
    end

    create index(:satellites, [:planet_id])
  end
end
