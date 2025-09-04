defmodule SelectoTest.Ecommerce.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "products" do
    field :sku, :string
    field :name, :string
    field :description, :string
    field :price, :decimal
    field :cost, :decimal
    field :weight, :decimal
    field :dimensions, :map  # {length, width, height}
    field :status, Ecto.Enum, values: [:active, :inactive, :discontinued, :draft]
    field :type, Ecto.Enum, values: [:physical, :digital, :service, :bundle]
    field :tags, {:array, :string}
    field :attributes, :map  # Flexible product attributes
    field :search_vector, :string  # For full-text search
    
    # Hierarchical category relationship
    belongs_to :category, SelectoTest.Ecommerce.Category
    belongs_to :brand, SelectoTest.Ecommerce.Brand
    belongs_to :vendor, SelectoTest.Ecommerce.Vendor
    
    # Relationships
    has_many :variants, SelectoTest.Ecommerce.ProductVariant
    has_many :inventory_items, SelectoTest.Ecommerce.InventoryItem
    has_many :reviews, SelectoTest.Ecommerce.Review
    has_many :order_items, SelectoTest.Ecommerce.OrderItem
    has_many :cart_items, SelectoTest.Ecommerce.CartItem
    
    # Many-to-many relationships
    many_to_many :related_products, __MODULE__,
      join_through: SelectoTest.Ecommerce.ProductRelation
    
    many_to_many :collections, SelectoTest.Ecommerce.Collection,
      join_through: SelectoTest.Ecommerce.ProductCollection
    
    # Slowly changing dimension
    has_many :product_history, SelectoTest.Ecommerce.ProductHistory
    
    timestamps()
  end
  
  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:sku, :name, :description, :price, :cost, :weight,
                    :dimensions, :status, :type, :tags, :attributes,
                    :category_id, :brand_id, :vendor_id])
    |> validate_required([:sku, :name, :price, :status, :type])
    |> unique_constraint(:sku)
    |> validate_number(:price, greater_than: 0)
  end
end