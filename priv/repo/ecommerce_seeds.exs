# Comprehensive seed data for e-commerce schema testing
# Tests all relationship types: hierarchical, many-to-many, SCD, and complex joins

alias SelectoTest.Repo
alias SelectoTest.Ecommerce.{
  User, Group, UserGroup, UserHistory,
  Category, Brand, Vendor, 
  Product, ProductVariant, ProductRelation,
  Address, Coupon, Order, OrderItem,
  Warehouse, InventoryItem, Transfer
}
import Ecto.Query

# Clear existing data
Repo.delete_all(Transfer)
Repo.delete_all(InventoryItem)
Repo.delete_all(OrderItem)
Repo.delete_all(Order)
Repo.delete_all(Address)
Repo.delete_all(Coupon)
Repo.delete_all(ProductRelation)
Repo.delete_all(ProductVariant)
Repo.delete_all(Product)
Repo.delete_all(UserHistory)
Repo.delete_all(UserGroup)
Repo.delete_all(User)
Repo.delete_all(Group)
Repo.delete_all(Category)
Repo.delete_all(Brand)
Repo.delete_all(Vendor)
Repo.delete_all(Warehouse)

IO.puts("🧹 Cleared existing data")

# ====================
# Groups
# ====================
vip_group = Repo.insert!(%Group{
  name: "VIP Customers",
  description: "High-value customers with special privileges",
  type: :vip,
  discount_percentage: Decimal.new("20.0"),
  priority: 100,
  permissions: ["early_access", "free_shipping", "priority_support"]
})

wholesale_group = Repo.insert!(%Group{
  name: "Wholesale Buyers",
  description: "Bulk purchase customers",
  type: :wholesale,
  discount_percentage: Decimal.new("15.0"),
  priority: 80,
  permissions: ["bulk_pricing", "net_30_payment"]
})

staff_group = Repo.insert!(%Group{
  name: "Staff Members",
  description: "Company employees",
  type: :customer_segment,
  discount_percentage: Decimal.new("30.0"),
  priority: 90,
  permissions: ["employee_discount", "internal_access"]
})

IO.puts("✅ Created #{Repo.aggregate(Group, :count)} groups")

# ====================
# Users with referral hierarchy
# ====================
# Top-level users (no referrer)
alice = Repo.insert!(%User{
  email: "alice@example.com",
  username: "alice",
  first_name: "Alice",
  last_name: "Anderson",
  status: "active",
  tier: "platinum",
  points: 5000,
  lifetime_value: Decimal.new("25000.00"),
  metadata: %{"source" => "organic", "campaign" => "launch"}
})

bob = Repo.insert!(%User{
  email: "bob@example.com",
  username: "bob",
  first_name: "Bob",
  last_name: "Brown",
  status: "active",
  tier: "gold",
  points: 3000,
  lifetime_value: Decimal.new("15000.00"),
  metadata: %{"source" => "paid", "campaign" => "summer2023"}
})

# Users referred by Alice
charlie = Repo.insert!(%User{
  email: "charlie@example.com",
  username: "charlie",
  first_name: "Charlie",
  last_name: "Chen",
  referrer_id: alice.id,
  status: "active",
  tier: "silver",
  points: 1500,
  lifetime_value: Decimal.new("8000.00")
})

diana = Repo.insert!(%User{
  email: "diana@example.com",
  username: "diana",
  first_name: "Diana",
  last_name: "Davis",
  referrer_id: alice.id,
  status: "active",
  tier: "bronze",
  points: 500
})

# User referred by Charlie (multi-level)
eve = Repo.insert!(%User{
  email: "eve@example.com",
  username: "eve",
  first_name: "Eve",
  last_name: "Evans",
  referrer_id: charlie.id,
  status: "active",
  tier: "bronze",
  points: 200
})

# Inactive user
frank = Repo.insert!(%User{
  email: "frank@example.com",
  username: "frank",
  first_name: "Frank",
  last_name: "Foster",
  status: "suspended",
  tier: "bronze",
  metadata: %{"suspension_reason" => "payment_issue"}
})

IO.puts("✅ Created #{Repo.aggregate(User, :count)} users with referral hierarchy")

# ====================
# User-Group associations (many-to-many)
# ====================
Repo.insert!(%UserGroup{user_id: alice.id, group_id: vip_group.id, joined_at: ~U[2023-01-15 10:00:00Z]})
Repo.insert!(%UserGroup{user_id: alice.id, group_id: staff_group.id, joined_at: ~U[2023-03-01 09:00:00Z]})
Repo.insert!(%UserGroup{user_id: bob.id, group_id: vip_group.id, joined_at: ~U[2023-06-01 14:00:00Z]})
Repo.insert!(%UserGroup{user_id: charlie.id, group_id: wholesale_group.id, joined_at: ~U[2023-09-01 11:00:00Z]})

IO.puts("✅ Created #{Repo.aggregate(UserGroup, :count)} user-group associations")

# ====================
# User History (SCD Type 2)
# ====================
# Alice's tier progression
Repo.insert!(%UserHistory{
  user_key: alice.id,
  email: alice.email,
  username: alice.username,
  first_name: alice.first_name,
  last_name: alice.last_name,
  status: "active",
  role: "customer",
  preferences: %{"tier" => "bronze"},
  valid_from: ~U[2023-01-01 00:00:00Z],
  valid_to: ~U[2023-03-31 23:59:59Z],
  is_current: false,
  change_reason: "Initial registration",
  version: 1
})

Repo.insert!(%UserHistory{
  user_key: alice.id,
  email: alice.email,
  username: alice.username,
  first_name: alice.first_name,
  last_name: alice.last_name,
  status: "active",
  role: "customer",
  preferences: %{"tier" => "silver"},
  valid_from: ~U[2023-04-01 00:00:00Z],
  valid_to: ~U[2023-06-30 23:59:59Z],
  is_current: false,
  change_reason: "Tier upgrade",
  version: 2
})

Repo.insert!(%UserHistory{
  user_key: alice.id,
  email: alice.email,
  username: alice.username,
  first_name: alice.first_name,
  last_name: alice.last_name,
  status: "active",
  role: "customer",
  preferences: %{"tier" => "gold"},
  valid_from: ~U[2023-07-01 00:00:00Z],
  valid_to: ~U[2023-12-31 23:59:59Z],
  is_current: false,
  change_reason: "Tier upgrade",
  version: 3
})

Repo.insert!(%UserHistory{
  user_key: alice.id,
  email: alice.email,
  username: alice.username,
  first_name: alice.first_name,
  last_name: alice.last_name,
  status: "active",
  role: "customer",
  preferences: %{"tier" => "platinum"},
  valid_from: ~U[2024-01-01 00:00:00Z],
  valid_to: nil,  # Current state
  is_current: true,
  change_reason: "Tier upgrade",
  version: 4
})

IO.puts("✅ Created #{Repo.aggregate(UserHistory, :count)} user history records")

# ====================
# Categories with multiple hierarchies
# ====================
# Hierarchy 1: Parent-child using parent_id
electronics = Repo.insert!(%Category{
  name: "Electronics",
  slug: "electronics",
  description: "Electronic devices and accessories",
  is_active: true,
  display_order: 1
})

computers = Repo.insert!(%Category{
  name: "Computers",
  slug: "computers",
  parent_id: electronics.id,
  is_active: true,
  display_order: 1
})

laptops = Repo.insert!(%Category{
  name: "Laptops",
  slug: "laptops",
  parent_id: computers.id,
  is_active: true,
  display_order: 1
})

phones = Repo.insert!(%Category{
  name: "Phones",
  slug: "phones",
  parent_id: electronics.id,
  is_active: true,
  display_order: 2
})

# Hierarchy 2: Path-based
clothing = Repo.insert!(%Category{
  name: "Clothing",
  slug: "clothing",
  path: "/clothing",
  depth: 0,
  is_active: true,
  display_order: 2
})

mens_clothing = Repo.insert!(%Category{
  name: "Men's Clothing",
  slug: "mens-clothing",
  path: "/clothing/mens",
  depth: 1,
  is_active: true,
  display_order: 1
})

mens_shirts = Repo.insert!(%Category{
  name: "Men's Shirts",
  slug: "mens-shirts",
  path: "/clothing/mens/shirts",
  depth: 2,
  is_active: true,
  display_order: 1
})

# Hierarchy 3: Closure table paths
home = Repo.insert!(%Category{
  name: "Home & Garden",
  slug: "home-garden",
  ancestor_ids: [],
  is_active: true,
  display_order: 3
})

furniture = Repo.insert!(%Category{
  name: "Furniture",
  slug: "furniture",
  ancestor_ids: [home.id],
  is_active: true,
  display_order: 1
})

office_furniture = Repo.insert!(%Category{
  name: "Office Furniture",
  slug: "office-furniture",
  ancestor_ids: [home.id, furniture.id],
  is_active: true,
  display_order: 1
})

IO.puts("✅ Created #{Repo.aggregate(Category, :count)} categories with 3 hierarchy types")

# ====================
# Brands and Vendors
# ====================
apple_brand = Repo.insert!(%Brand{
  name: "Apple",
  slug: "apple",
  description: "Premium consumer electronics",
  website: "https://apple.com",
  is_featured: true
})

dell_brand = Repo.insert!(%Brand{
  name: "Dell",
  slug: "dell",
  description: "Business and consumer computers",
  website: "https://dell.com",
  is_featured: true
})

nike_brand = Repo.insert!(%Brand{
  name: "Nike",
  slug: "nike",
  description: "Athletic apparel and footwear",
  website: "https://nike.com",
  is_featured: true
})

tech_vendor = Repo.insert!(%Vendor{
  name: "TechSupply Co",
  code: "TECH001",
  email: "orders@techsupply.com",
  status: "active",
  commission_rate: Decimal.new("0.15"),
  metadata: %{"payment_terms" => "net30", "min_order" => 500}
})

fashion_vendor = Repo.insert!(%Vendor{
  name: "Fashion Direct",
  code: "FASH001",
  email: "sales@fashiondirect.com",
  status: "active",
  commission_rate: Decimal.new("0.20")
})

IO.puts("✅ Created #{Repo.aggregate(Brand, :count)} brands and #{Repo.aggregate(Vendor, :count)} vendors")

# ====================
# Products with variants
# ====================
macbook = Repo.insert!(%Product{
  sku: "MBP-2024",
  name: "MacBook Pro 14\"",
  description: "Professional laptop with M3 chip",
  price: Decimal.new("1999.00"),
  cost: Decimal.new("1400.00"),
  status: "active",
  type: "physical",
  category_id: laptops.id,
  brand_id: apple_brand.id,
  vendor_id: tech_vendor.id,
  tags: ["laptop", "professional", "m3"],
  attributes: %{
    "processor" => "Apple M3",
    "display" => "14.2-inch Liquid Retina XDR",
    "year" => 2024
  }
})

# MacBook variants
macbook_8gb = Repo.insert!(%ProductVariant{
  product_id: macbook.id,
  sku: "MBP-2024-8GB",
  name: "8GB RAM / 512GB SSD",
  price: Decimal.new("1999.00"),
  cost: Decimal.new("1400.00"),
  stock_quantity: 50,
  is_default: true,
  options: %{"ram" => "8GB", "storage" => "512GB"}
})

macbook_16gb = Repo.insert!(%ProductVariant{
  product_id: macbook.id,
  sku: "MBP-2024-16GB",
  name: "16GB RAM / 1TB SSD",
  price: Decimal.new("2399.00"),
  cost: Decimal.new("1680.00"),
  stock_quantity: 30,
  options: %{"ram" => "16GB", "storage" => "1TB"}
})

iphone = Repo.insert!(%Product{
  sku: "IPH-15-PRO",
  name: "iPhone 15 Pro",
  description: "Advanced smartphone with titanium design",
  price: Decimal.new("999.00"),
  cost: Decimal.new("650.00"),
  status: "active",
  type: "physical",
  category_id: phones.id,
  brand_id: apple_brand.id,
  vendor_id: tech_vendor.id,
  tags: ["smartphone", "5g", "titanium"]
})

nike_shirt = Repo.insert!(%Product{
  sku: "NIKE-DRI-001",
  name: "Nike Dri-FIT Running Shirt",
  description: "Moisture-wicking athletic shirt",
  price: Decimal.new("45.00"),
  cost: Decimal.new("18.00"),
  status: "active",
  type: "physical",
  category_id: mens_shirts.id,
  brand_id: nike_brand.id,
  vendor_id: fashion_vendor.id,
  tags: ["athletic", "running", "dri-fit"]
})

office_desk = Repo.insert!(%Product{
  sku: "DESK-ADJ-001",
  name: "Adjustable Standing Desk",
  description: "Electric height-adjustable desk",
  price: Decimal.new("599.00"),
  cost: Decimal.new("350.00"),
  status: "active",
  type: "physical",
  category_id: office_furniture.id,
  vendor_id: tech_vendor.id,
  tags: ["standing-desk", "adjustable", "ergonomic"],
  dimensions: %{"width" => 160, "depth" => 80, "height_min" => 70, "height_max" => 120}
})

IO.puts("✅ Created #{Repo.aggregate(Product, :count)} products with #{Repo.aggregate(ProductVariant, :count)} variants")

# ====================
# Product Relations
# ====================
# iPhone accessories related to iPhone
Repo.insert!(%ProductRelation{
  product_id: iphone.id,
  related_product_id: macbook.id,
  relation_type: "cross-sell"
})

# MacBook related to iPhone (ecosystem)
Repo.insert!(%ProductRelation{
  product_id: macbook.id,
  related_product_id: iphone.id,
  relation_type: "cross-sell"
})

IO.puts("✅ Created #{Repo.aggregate(ProductRelation, :count)} product relations")

# ====================
# Warehouses with hierarchy
# ====================
central_warehouse = Repo.insert!(%Warehouse{
  code: "WH-CENTRAL",
  name: "Central Distribution Center",
  type: "distribution",
  status: "active",
  capacity: 100000,
  current_stock: 45000,
  location: %{
    "address" => "123 Logistics Way",
    "city" => "Chicago",
    "state" => "IL",
    "zip" => "60601",
    "coordinates" => %{"lat" => 41.8781, "lng" => -87.6298}
  },
  capabilities: ["shipping", "receiving", "cross-docking"]
})

east_warehouse = Repo.insert!(%Warehouse{
  code: "WH-EAST",
  name: "East Coast Fulfillment",
  type: "fulfillment",
  status: "active",
  parent_id: central_warehouse.id,
  capacity: 50000,
  current_stock: 22000,
  location: %{
    "address" => "456 Commerce Blvd",
    "city" => "Newark",
    "state" => "NJ",
    "zip" => "07102"
  },
  capabilities: ["shipping", "same-day"]
})

west_warehouse = Repo.insert!(%Warehouse{
  code: "WH-WEST",
  name: "West Coast Fulfillment",
  type: "fulfillment",
  status: "active",
  parent_id: central_warehouse.id,
  capacity: 60000,
  current_stock: 35000,
  location: %{
    "address" => "789 Distribution Ave",
    "city" => "Los Angeles",
    "state" => "CA",
    "zip" => "90001"
  },
  capabilities: ["shipping", "receiving"]
})

IO.puts("✅ Created #{Repo.aggregate(Warehouse, :count)} warehouses with hierarchy")

# ====================
# Inventory Items
# ====================
Repo.insert!(%InventoryItem{
  warehouse_id: central_warehouse.id,
  product_id: macbook.id,
  product_variant_id: macbook_8gb.id,
  quantity_available: 25,
  quantity_reserved: 5,
  quantity_incoming: 10,
  reorder_point: 20,
  reorder_quantity: 50,
  location_in_warehouse: "A-15-3"
})

Repo.insert!(%InventoryItem{
  warehouse_id: east_warehouse.id,
  product_id: macbook.id,
  product_variant_id: macbook_8gb.id,
  quantity_available: 15,
  quantity_reserved: 2,
  reorder_point: 10,
  reorder_quantity: 25,
  location_in_warehouse: "B-8-2"
})

Repo.insert!(%InventoryItem{
  warehouse_id: west_warehouse.id,
  product_id: macbook.id,
  product_variant_id: macbook_16gb.id,
  quantity_available: 30,
  quantity_reserved: 8,
  reorder_point: 15,
  reorder_quantity: 30,
  location_in_warehouse: "C-12-5"
})

Repo.insert!(%InventoryItem{
  warehouse_id: central_warehouse.id,
  product_id: iphone.id,
  quantity_available: 200,
  quantity_reserved: 50,
  quantity_incoming: 100,
  reorder_point: 100,
  reorder_quantity: 500
})

IO.puts("✅ Created #{Repo.aggregate(InventoryItem, :count)} inventory items")

# ====================
# Transfers
# ====================
Repo.insert!(%Transfer{
  transfer_number: "TRF-2024-001",
  from_warehouse_id: central_warehouse.id,
  to_warehouse_id: east_warehouse.id,
  status: "completed",
  scheduled_date: ~D[2024-01-15],
  shipped_date: ~U[2024-01-15 14:00:00Z],
  received_date: ~U[2024-01-16 10:00:00Z],
  notes: "Regular inventory replenishment"
})

Repo.insert!(%Transfer{
  transfer_number: "TRF-2024-002",
  from_warehouse_id: central_warehouse.id,
  to_warehouse_id: west_warehouse.id,
  status: "in_transit",
  scheduled_date: ~D[2024-01-20],
  shipped_date: ~U[2024-01-20 09:00:00Z],
  notes: "Emergency stock transfer for high demand"
})

IO.puts("✅ Created #{Repo.aggregate(Transfer, :count)} transfers")

# ====================
# Addresses
# ====================
alice_home = Repo.insert!(%Address{
  user_id: alice.id,
  type: "shipping",
  is_default: true,
  recipient_name: "Alice Anderson",
  street_address_1: "123 Main St",
  street_address_2: "Apt 4B",
  city: "San Francisco",
  state_province: "CA",
  postal_code: "94102",
  country_code: "US",
  phone: "415-555-0100"
})

alice_work = Repo.insert!(%Address{
  user_id: alice.id,
  type: "shipping",
  is_default: false,
  recipient_name: "Alice Anderson",
  company: "TechCorp",
  street_address_1: "456 Market St",
  city: "San Francisco",
  state_province: "CA",
  postal_code: "94103",
  country_code: "US",
  phone: "415-555-0101"
})

bob_home = Repo.insert!(%Address{
  user_id: bob.id,
  type: "shipping",
  is_default: true,
  recipient_name: "Bob Brown",
  street_address_1: "789 Oak Ave",
  city: "Los Angeles",
  state_province: "CA",
  postal_code: "90001",
  country_code: "US"
})

IO.puts("✅ Created #{Repo.aggregate(Address, :count)} addresses")

# ====================
# Coupons
# ====================
vip_coupon = Repo.insert!(%Coupon{
  code: "VIP2024",
  description: "VIP customer discount",
  discount_type: "percentage",
  discount_value: Decimal.new("20"),
  minimum_amount: Decimal.new("100"),
  usage_limit: 1000,
  used_count: 42,
  valid_from: ~U[2024-01-01 00:00:00Z],
  valid_until: ~U[2024-12-31 23:59:59Z],
  is_active: true
})

new_year_coupon = Repo.insert!(%Coupon{
  code: "NEWYEAR25",
  description: "New Year 2025 Special",
  discount_type: "fixed",
  discount_value: Decimal.new("25"),
  minimum_amount: Decimal.new("75"),
  valid_from: ~U[2024-12-26 00:00:00Z],
  valid_until: ~U[2025-01-15 23:59:59Z],
  is_active: true
})

IO.puts("✅ Created #{Repo.aggregate(Coupon, :count)} coupons")

# ====================
# Orders with Items
# ====================
alice_order1 = Repo.insert!(%Order{
  order_number: "ORD-2024-0001",
  user_id: alice.id,
  status: "delivered",
  payment_status: "paid",
  fulfillment_status: "fulfilled",
  subtotal: Decimal.new("2044.00"),
  tax_amount: Decimal.new("178.85"),
  shipping_amount: Decimal.new("0.00"),
  discount_amount: Decimal.new("408.80"),
  total_amount: Decimal.new("1814.05"),
  currency: "USD",
  shipping_address_id: alice_home.id,
  billing_address_id: alice_home.id,
  coupon_id: vip_coupon.id,
  metadata: %{"source" => "web", "device" => "desktop"}
})

# Order items for Alice's order
Repo.insert!(%OrderItem{
  order_id: alice_order1.id,
  product_id: macbook.id,
  product_variant_id: macbook_8gb.id,
  product_name: "MacBook Pro 14\"",
  product_sku: "MBP-2024-8GB",
  quantity: 1,
  unit_price: Decimal.new("1999.00"),
  discount_amount: Decimal.new("399.80"),
  tax_amount: Decimal.new("174.83"),
  total_amount: Decimal.new("1774.03")
})

Repo.insert!(%OrderItem{
  order_id: alice_order1.id,
  product_id: nike_shirt.id,
  product_name: "Nike Dri-FIT Running Shirt",
  product_sku: "NIKE-DRI-001",
  quantity: 1,
  unit_price: Decimal.new("45.00"),
  discount_amount: Decimal.new("9.00"),
  tax_amount: Decimal.new("4.02"),
  total_amount: Decimal.new("40.02")
})

bob_order1 = Repo.insert!(%Order{
  order_number: "ORD-2024-0002",
  user_id: bob.id,
  status: "processing",
  payment_status: "paid",
  fulfillment_status: "partial",
  subtotal: Decimal.new("999.00"),
  tax_amount: Decimal.new("87.41"),
  shipping_amount: Decimal.new("15.00"),
  total_amount: Decimal.new("1101.41"),
  currency: "USD",
  shipping_address_id: bob_home.id,
  billing_address_id: bob_home.id
})

Repo.insert!(%OrderItem{
  order_id: bob_order1.id,
  product_id: iphone.id,
  product_name: "iPhone 15 Pro",
  product_sku: "IPH-15-PRO",
  quantity: 1,
  unit_price: Decimal.new("999.00"),
  tax_amount: Decimal.new("87.41"),
  total_amount: Decimal.new("1086.41")
})

charlie_order1 = Repo.insert!(%Order{
  order_number: "ORD-2024-0003",
  user_id: charlie.id,
  status: "pending",
  payment_status: "pending",
  fulfillment_status: "unfulfilled",
  subtotal: Decimal.new("599.00"),
  tax_amount: Decimal.new("52.41"),
  shipping_amount: Decimal.new("25.00"),
  total_amount: Decimal.new("676.41"),
  currency: "USD"
})

Repo.insert!(%OrderItem{
  order_id: charlie_order1.id,
  product_id: office_desk.id,
  product_name: "Adjustable Standing Desk",
  product_sku: "DESK-ADJ-001",
  quantity: 1,
  unit_price: Decimal.new("599.00"),
  tax_amount: Decimal.new("52.41"),
  total_amount: Decimal.new("651.41")
})

IO.puts("✅ Created #{Repo.aggregate(Order, :count)} orders with #{Repo.aggregate(OrderItem, :count)} items")

# ====================
# Summary Statistics
# ====================
IO.puts("\n📊 Database Summary:")
IO.puts("   Users: #{Repo.aggregate(User, :count)}")
IO.puts("   Groups: #{Repo.aggregate(Group, :count)}")
IO.puts("   User-Groups: #{Repo.aggregate(UserGroup, :count)}")
IO.puts("   User History: #{Repo.aggregate(UserHistory, :count)}")
IO.puts("   Categories: #{Repo.aggregate(Category, :count)}")
IO.puts("   Brands: #{Repo.aggregate(Brand, :count)}")
IO.puts("   Vendors: #{Repo.aggregate(Vendor, :count)}")
IO.puts("   Products: #{Repo.aggregate(Product, :count)}")
IO.puts("   Product Variants: #{Repo.aggregate(ProductVariant, :count)}")
IO.puts("   Product Relations: #{Repo.aggregate(ProductRelation, :count)}")
IO.puts("   Warehouses: #{Repo.aggregate(Warehouse, :count)}")
IO.puts("   Inventory Items: #{Repo.aggregate(InventoryItem, :count)}")
IO.puts("   Transfers: #{Repo.aggregate(Transfer, :count)}")
IO.puts("   Addresses: #{Repo.aggregate(Address, :count)}")
IO.puts("   Coupons: #{Repo.aggregate(Coupon, :count)}")
IO.puts("   Orders: #{Repo.aggregate(Order, :count)}")
IO.puts("   Order Items: #{Repo.aggregate(OrderItem, :count)}")

# ====================
# Relationship Validation
# ====================
IO.puts("\n✅ Validating relationships:")

# Check referral hierarchy
referral_tree = Repo.all(
  from u in User,
  left_join: r in User, on: r.referrer_id == u.id,
  where: is_nil(u.referrer_id),
  group_by: u.id,
  select: {u.username, count(r.id)}
)
IO.puts("   Referral trees: #{inspect(referral_tree)}")

# Check many-to-many groups
user_group_counts = Repo.all(
  from ug in UserGroup,
  join: u in User, on: u.id == ug.user_id,
  join: g in Group, on: g.id == ug.group_id,
  group_by: u.username,
  select: {u.username, count(g.id)}
)
IO.puts("   User group memberships: #{inspect(user_group_counts)}")

# Check category hierarchies
cat_with_parent = Repo.aggregate(from(c in Category, where: not is_nil(c.parent_id)), :count)
cat_with_path = Repo.aggregate(from(c in Category, where: not is_nil(c.path)), :count)
cat_with_ancestors = Repo.aggregate(from(c in Category, where: fragment("array_length(?, 1) > 0", c.ancestor_ids)), :count)
IO.puts("   Categories with parent_id: #{cat_with_parent}")
IO.puts("   Categories with path: #{cat_with_path}")
IO.puts("   Categories with ancestors: #{cat_with_ancestors}")

# Check product relationships
products_with_relations = Repo.all(
  from p in Product,
  left_join: pr in ProductRelation, on: pr.product_id == p.id,
  group_by: p.name,
  having: count(pr.id) > 0,
  select: {p.name, count(pr.id)}
)
IO.puts("   Products with relations: #{inspect(products_with_relations)}")

# Check warehouse hierarchy
warehouse_tree = Repo.all(
  from w in Warehouse,
  left_join: c in Warehouse, on: c.parent_id == w.id,
  where: is_nil(w.parent_id),
  group_by: w.name,
  select: {w.name, count(c.id)}
)
IO.puts("   Warehouse hierarchy: #{inspect(warehouse_tree)}")

IO.puts("\n✅ Seed data generation complete!")