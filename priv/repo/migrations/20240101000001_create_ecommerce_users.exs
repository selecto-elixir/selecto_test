defmodule SelectoTest.Repo.Migrations.CreateEcommerceUsers do
  use Ecto.Migration

  def change do
    # Create users table with UUID primary key
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :username, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :phone, :string
      add :status, :string, null: false, default: "active"
      add :role, :string, null: false, default: "customer"
      add :preferences, :map, default: %{}
      add :tags, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      
      # Self-referential for referral system
      add :referrer_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      
      timestamps()
    end
    
    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
    create index(:users, [:status])
    create index(:users, [:role])
    create index(:users, [:referrer_id])
  end
end