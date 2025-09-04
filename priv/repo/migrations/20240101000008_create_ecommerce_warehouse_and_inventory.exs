defmodule SelectoTest.Repo.Migrations.CreateEcommerceWarehouseAndInventory do
  use Ecto.Migration

  def change do
    # Warehouses table
    create table(:warehouses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :type, :string, null: false, default: "fulfillment"
      add :status, :string, null: false, default: "active"
      add :capacity, :integer
      add :current_stock, :integer, default: 0
      add :location, :map
      add :operating_hours, :map
      add :capabilities, {:array, :string}, default: []
      
      # Hierarchical warehouse network
      add :parent_id, references(:warehouses, type: :binary_id, on_delete: :nilify_all)
      
      timestamps()
    end
    
    create unique_index(:warehouses, [:code])
    create index(:warehouses, [:status])
    create index(:warehouses, [:type])
    create index(:warehouses, [:parent_id])
    
    # Inventory items table
    create table(:inventory_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :warehouse_id, references(:warehouses, type: :binary_id, on_delete: :restrict), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :restrict), null: false
      add :product_variant_id, references(:product_variants, type: :binary_id, on_delete: :restrict)
      add :quantity_available, :integer, null: false, default: 0
      add :quantity_reserved, :integer, default: 0
      add :quantity_incoming, :integer, default: 0
      add :reorder_point, :integer
      add :reorder_quantity, :integer
      add :location_in_warehouse, :string
      add :last_counted_at, :utc_datetime
      
      timestamps()
    end
    
    create unique_index(:inventory_items, [:warehouse_id, :product_id, :product_variant_id])
    create index(:inventory_items, [:product_id])
    create index(:inventory_items, [:quantity_available])
    
    # Transfers between warehouses
    create table(:transfers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :transfer_number, :string, null: false
      add :from_warehouse_id, references(:warehouses, type: :binary_id, on_delete: :restrict), null: false
      add :to_warehouse_id, references(:warehouses, type: :binary_id, on_delete: :restrict), null: false
      add :status, :string, null: false, default: "pending"
      add :scheduled_date, :date
      add :shipped_date, :utc_datetime
      add :received_date, :utc_datetime
      add :notes, :text
      
      timestamps()
    end
    
    create unique_index(:transfers, [:transfer_number])
    create index(:transfers, [:from_warehouse_id])
    create index(:transfers, [:to_warehouse_id])
    create index(:transfers, [:status])
  end
end