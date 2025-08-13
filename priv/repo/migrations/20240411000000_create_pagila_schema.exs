defmodule SelectoTest.Repo.Migrations.CreatePagilaSchema do
  use Ecto.Migration

  def up do

  end

  # def change do
  #   # Language table
  #   create table(:language, primary_key: false) do
  #     add :language_id, :serial, primary_key: true
  #     add :name, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Actor table
  #   create table(:actor, primary_key: false) do
  #     add :actor_id, :serial, primary_key: true
  #     add :first_name, :string, null: false
  #     add :last_name, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Category table
  #   create table(:category, primary_key: false) do
  #     add :category_id, :id, primary_key: true
  #     add :name, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Country table
  #   create table(:country, primary_key: false) do
  #     add :country_id, :id, primary_key: true
  #     add :country, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # City table
  #   create table(:city, primary_key: false) do
  #     add :city_id, :id, primary_key: true
  #     add :city, :string, null: false
  #     add :country_id, references(:country, column: :country_id), null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Address table
  #   create table(:address, primary_key: false) do
  #     add :address_id, :id, primary_key: true
  #     add :address, :string, null: false
  #     add :address2, :string
  #     add :district, :string, null: false
  #     add :city_id, references(:city, column: :city_id), null: false
  #     add :postal_code, :string
  #     add :phone, :string, null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Store table
  #   create table(:store, primary_key: false) do
  #     add :store_id, :id, primary_key: true
  #     add :manager_staff_id, :integer, null: false
  #     add :address_id, references(:address, column: :address_id), null: false
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Staff table
  #   create table(:staff, primary_key: false) do
  #     add :staff_id, :id, primary_key: true
  #     add :first_name, :string, null: false
  #     add :last_name, :string, null: false
  #     add :address_id, references(:address, column: :address_id), null: false
  #     add :email, :string
  #     add :store_id, references(:store, column: :store_id), null: false
  #     add :active, :boolean, default: true
  #     add :username, :string, null: false
  #     add :password, :string
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Customer table
  #   create table(:customer, primary_key: false) do
  #     add :customer_id, :id, primary_key: true
  #     add :store_id, references(:store, column: :store_id), null: false
  #     add :first_name, :string, null: false
  #     add :last_name, :string, null: false
  #     add :email, :string
  #     add :address_id, references(:address, column: :address_id), null: false
  #     add :activebool, :boolean, default: true
  #     add :create_date, :date, default: fragment("CURRENT_DATE")
  #     add :active, :integer
  #     timestamps(type: :utc_datetime, default: fragment("NOW()"))
  #   end

  #   # Film table
  #   create table(:film, primary_key: false) do
  #     add :film_id, :serial, primary_key: true
  #     add :title, :string, null: false
  #     add :description, :text
  #     add :release_year, :integer
  #     add :language_id, references(:language, column: :language_id), null: false
  #     add :rental_duration, :integer, default: 3, null: false
  #     add :rental_rate, :decimal, precision: 4, scale: 2, default: 4.99, null: false
  #     add :length, :integer
  #     add :replacement_cost, :decimal, precision: 5, scale: 2, default: 19.99, null: false
  #     add :rating, :string, default: "G"
  #     add :special_features, {:array, :string}
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Film Actor junction table
  #   create table(:film_actor, primary_key: false) do
  #     add :actor_id, references(:actor, column: :actor_id), null: false
  #     add :film_id, references(:film, column: :film_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Film Category junction table
  #   create table(:film_category, primary_key: false) do
  #     add :film_id, references(:film, column: :film_id), null: false
  #     add :category_id, references(:category, column: :category_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Inventory table
  #   create table(:inventory, primary_key: false) do
  #     add :inventory_id, :id, primary_key: true
  #     add :film_id, references(:film, column: :film_id), null: false
  #     add :store_id, references(:store, column: :store_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Rental table
  #   create table(:rental, primary_key: false) do
  #     add :rental_id, :id, primary_key: true
  #     add :rental_date, :utc_datetime, null: false
  #     add :inventory_id, references(:inventory, column: :inventory_id), null: false
  #     add :customer_id, references(:customer, column: :customer_id), null: false
  #     add :return_date, :utc_datetime
  #     add :staff_id, references(:staff, column: :staff_id), null: false
  #     add :last_update, :utc_datetime, default: fragment("NOW()"), null: false
  #   end

  #   # Payment table
  #   create table(:payment, primary_key: false) do
  #     add :payment_id, :id, primary_key: true
  #     add :customer_id, references(:customer, column: :customer_id), null: false
  #     add :staff_id, references(:staff, column: :staff_id), null: false
  #     add :rental_id, references(:rental, column: :rental_id)
  #     add :amount, :decimal, precision: 5, scale: 2, null: false
  #     add :payment_date, :utc_datetime, null: false
  #   end

  #   # Create composite primary keys for junction tables
  #   create unique_index(:film_actor, [:actor_id, :film_id])
  #   create unique_index(:film_category, [:film_id, :category_id])

  #   # Create indexes for foreign keys
  #   create index(:city, [:country_id])
  #   create index(:address, [:city_id])
  #   create index(:store, [:address_id])
  #   create index(:staff, [:address_id, :store_id])
  #   create index(:customer, [:store_id, :address_id])
  #   create index(:film, [:language_id])
  #   create index(:film_actor, [:actor_id])
  #   create index(:film_actor, [:film_id])
  #   create index(:film_category, [:film_id])
  #   create index(:film_category, [:category_id])
  #   create index(:inventory, [:film_id, :store_id])
  #   create index(:rental, [:inventory_id, :customer_id, :staff_id])
  #   create index(:payment, [:customer_id, :staff_id, :rental_id])
  # end
end
