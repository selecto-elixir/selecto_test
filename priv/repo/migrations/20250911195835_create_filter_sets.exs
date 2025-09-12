defmodule SelectoTest.Repo.Migrations.CreateFilterSets do
  use Ecto.Migration

  def change do
    create table(:filter_sets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :domain, :string, null: false
      add :filters, :map, null: false
      add :user_id, :string, null: false
      add :is_default, :boolean, default: false, null: false
      add :is_shared, :boolean, default: false, null: false
      add :is_system, :boolean, default: false, null: false
      add :usage_count, :integer, default: 0, null: false

      timestamps()
    end

    create index(:filter_sets, [:user_id, :domain])
    create index(:filter_sets, [:domain, :is_shared])
    create index(:filter_sets, [:domain, :is_system])
    create index(:filter_sets, [:user_id, :is_default])
  end
end