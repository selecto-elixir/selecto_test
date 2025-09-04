defmodule SelectoTest.Repo.Migrations.CreateEcommerceAddresses do
  use Ecto.Migration

  def change do
    create table(:addresses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :type, :string, default: "shipping"
      add :is_default, :boolean, default: false
      add :recipient_name, :string
      add :company, :string
      add :street_address_1, :string, null: false
      add :street_address_2, :string
      add :city, :string, null: false
      add :state_province, :string, null: false
      add :postal_code, :string, null: false
      add :country_code, :string, null: false, default: "US"
      add :phone, :string
      add :instructions, :text
      
      timestamps()
    end
    
    create index(:addresses, [:user_id])
    create index(:addresses, [:type])
    create index(:addresses, [:is_default])
  end
end