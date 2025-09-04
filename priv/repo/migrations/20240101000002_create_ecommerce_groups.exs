defmodule SelectoTest.Repo.Migrations.CreateEcommerceGroups do
  use Ecto.Migration

  def change do
    # Groups for customer segmentation
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :string
      add :type, :string, null: false
      add :permissions, {:array, :string}, default: []
      add :discount_percentage, :decimal
      add :priority, :integer, default: 0
      
      timestamps()
    end
    
    create unique_index(:groups, [:name])
    create index(:groups, [:type])
    
    # Junction table for many-to-many user-group relationship
    create table(:user_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, default: "member"
      add :joined_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :is_active, :boolean, default: true
      
      timestamps()
    end
    
    create unique_index(:user_groups, [:user_id, :group_id])
    create index(:user_groups, [:group_id])
    create index(:user_groups, [:is_active])
  end
end