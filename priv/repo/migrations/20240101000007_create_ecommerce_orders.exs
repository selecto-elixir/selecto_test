defmodule SelectoTest.Repo.Migrations.CreateEcommerceOrders do
  use Ecto.Migration

  def change do
    # Coupons table (needed for orders)
    create table(:coupons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :description, :string
      add :discount_type, :string, null: false  # percentage, fixed
      add :discount_value, :decimal, null: false
      add :minimum_amount, :decimal
      add :usage_limit, :integer
      add :used_count, :integer, default: 0
      add :valid_from, :utc_datetime
      add :valid_until, :utc_datetime
      add :is_active, :boolean, default: true
      
      timestamps()
    end
    
    create unique_index(:coupons, [:code])
    create index(:coupons, [:is_active])
    
    # Orders table
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_number, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :payment_status, :string, null: false, default: "pending"
      add :fulfillment_status, :string, null: false, default: "unfulfilled"
      add :subtotal, :decimal, null: false
      add :tax_amount, :decimal, default: 0
      add :shipping_amount, :decimal, default: 0
      add :discount_amount, :decimal, default: 0
      add :total_amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :notes, :text
      add :metadata, :map, default: %{}
      
      # Foreign keys
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :shipping_address_id, references(:addresses, type: :binary_id, on_delete: :restrict)
      add :billing_address_id, references(:addresses, type: :binary_id, on_delete: :restrict)
      add :coupon_id, references(:coupons, type: :binary_id, on_delete: :nilify_all)
      
      timestamps()
    end
    
    create unique_index(:orders, [:order_number])
    create index(:orders, [:user_id])
    create index(:orders, [:status])
    create index(:orders, [:payment_status])
    create index(:orders, [:fulfillment_status])
    create index(:orders, [:inserted_at])
    
    # Order items table
    create table(:order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :restrict), null: false
      add :product_variant_id, references(:product_variants, type: :binary_id, on_delete: :nilify_all)
      add :product_name, :string, null: false  # Denormalized for history
      add :product_sku, :string, null: false   # Denormalized for history
      add :quantity, :integer, null: false
      add :unit_price, :decimal, null: false
      add :discount_amount, :decimal, default: 0
      add :tax_amount, :decimal, default: 0
      add :total_amount, :decimal, null: false
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create index(:order_items, [:order_id])
    create index(:order_items, [:product_id])
  end
end