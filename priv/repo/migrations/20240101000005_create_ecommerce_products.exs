defmodule SelectoTest.Repo.Migrations.CreateEcommerceProducts do
  use Ecto.Migration

  def change do
    # Products table
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sku, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :price, :decimal, null: false
      add :cost, :decimal
      add :weight, :decimal
      add :dimensions, :map
      add :status, :string, null: false, default: "active"
      add :type, :string, null: false, default: "physical"
      add :tags, {:array, :string}, default: []
      add :attributes, :map, default: %{}
      add :search_vector, :text
      
      # Foreign keys
      add :category_id, references(:categories, type: :binary_id, on_delete: :nilify_all)
      add :brand_id, references(:brands, type: :binary_id, on_delete: :nilify_all)
      add :vendor_id, references(:vendors, type: :binary_id, on_delete: :restrict)
      
      timestamps()
    end
    
    create unique_index(:products, [:sku])
    create index(:products, [:status])
    create index(:products, [:type])
    create index(:products, [:category_id])
    create index(:products, [:brand_id])
    create index(:products, [:vendor_id])
    create index(:products, [:price])
    
    # Product variants table
    create table(:product_variants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false
      add :sku, :string, null: false
      add :name, :string
      add :options, :map
      add :price, :decimal
      add :cost, :decimal
      add :weight, :decimal
      add :stock_quantity, :integer, default: 0
      add :is_default, :boolean, default: false
      
      timestamps()
    end
    
    create unique_index(:product_variants, [:sku])
    create index(:product_variants, [:product_id])
    
    # Product relations (for related products)
    create table(:product_relations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false
      add :related_product_id, references(:products, type: :binary_id, on_delete: :delete_all), null: false
      add :relation_type, :string, default: "related"
      
      timestamps()
    end
    
    create unique_index(:product_relations, [:product_id, :related_product_id])
    create index(:product_relations, [:related_product_id])
  end
end