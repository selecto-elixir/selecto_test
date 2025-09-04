defmodule SelectoTest.Repo.Migrations.CreateEcommerceVendorsAndBrands do
  use Ecto.Migration

  def change do
    # Vendors table
    create table(:vendors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :code, :string, null: false
      add :email, :string
      add :phone, :string
      add :address, :map
      add :status, :string, default: "active"
      add :commission_rate, :decimal
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create unique_index(:vendors, [:code])
    create index(:vendors, [:status])
    
    # Brands table
    create table(:brands, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :logo_url, :string
      add :description, :string
      add :website, :string
      add :is_featured, :boolean, default: false
      
      timestamps()
    end
    
    create unique_index(:brands, [:slug])
    create index(:brands, [:is_featured])
  end
end