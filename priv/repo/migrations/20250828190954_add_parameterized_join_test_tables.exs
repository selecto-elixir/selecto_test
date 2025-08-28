defmodule SelectoTest.Repo.Migrations.AddParameterizedJoinTestTables do
  use Ecto.Migration

  def change do
    # Product categories for parameterized testing
    create table(:product_categories) do
      add :name, :string, null: false, size: 100
      add :parent_id, references(:product_categories, on_delete: :nilify_all)
      add :active, :boolean, default: true
      add :description, :text
      add :sort_order, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:product_categories, [:parent_id])
    create index(:product_categories, [:active])
    create index(:product_categories, [:name])

    # Enhanced products table for parameterized join testing
    create table(:parameterized_products) do
      add :name, :string, null: false
      add :description, :text
      add :price, :decimal, precision: 10, scale: 2
      add :category_id, references(:product_categories, on_delete: :restrict)
      add :active, :boolean, default: true
      add :featured, :boolean, default: false
      add :min_price_threshold, :decimal, precision: 10, scale: 2, default: 0.0
      add :inventory_count, :integer, default: 0
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:parameterized_products, [:category_id])
    create index(:parameterized_products, [:active])
    create index(:parameterized_products, [:featured])
    create index(:parameterized_products, [:price])

    # Seasonal discounts for multi-parameter testing
    create table(:seasonal_discounts) do
      add :product_id, references(:parameterized_products, on_delete: :delete_all), null: false
      add :season, :string, null: false  # spring, summer, fall, winter
      add :tier, :string, null: false    # standard, premium, vip
      add :discount_percent, :decimal, precision: 5, scale: 2, null: false
      add :active, :boolean, default: true
      add :start_date, :date
      add :end_date, :date
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create index(:seasonal_discounts, [:product_id])
    create index(:seasonal_discounts, [:season])
    create index(:seasonal_discounts, [:tier])
    create index(:seasonal_discounts, [:active])
    create unique_index(:seasonal_discounts, [:product_id, :season, :tier])

    # Test users table for parameterized join testing
    create table(:test_users) do
      add :name, :string, null: false
      add :email, :string
      add :role, :string, default: "customer"  # customer, admin, staff
      add :active, :boolean, default: true
      add :subscription_tier, :string, default: "standard"  # standard, premium, vip
      add :region, :string, default: "US"  # US, EU, APAC

      timestamps(type: :utc_datetime)
    end

    create index(:test_users, [:active])
    create index(:test_users, [:role])
    create index(:test_users, [:subscription_tier])
    create index(:test_users, [:region])
    create unique_index(:test_users, [:email])

    # User preferences for boolean parameter testing
    create table(:user_preferences) do
      add :user_id, references(:test_users, on_delete: :delete_all)
      add :preference_key, :string, null: false, size: 100
      add :preference_value, :map  # JSONB equivalent
      add :is_active, :boolean, default: true
      add :priority, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:user_preferences, [:user_id])
    create index(:user_preferences, [:preference_key])
    create index(:user_preferences, [:is_active])
    create unique_index(:user_preferences, [:user_id, :preference_key])

    # Product reviews for testing complex parameterized joins
    create table(:product_reviews) do
      add :product_id, references(:parameterized_products, on_delete: :delete_all), null: false
      add :user_id, references(:test_users, on_delete: :delete_all)
      add :rating, :integer, null: false  # 1-5 stars
      add :title, :string
      add :content, :text
      add :verified_purchase, :boolean, default: false
      add :helpful_votes, :integer, default: 0
      add :status, :string, default: "published"  # draft, published, hidden
      add :sentiment, :string  # positive, negative, neutral

      timestamps(type: :utc_datetime)
    end

    create index(:product_reviews, [:product_id])
    create index(:product_reviews, [:user_id])
    create index(:product_reviews, [:rating])
    create index(:product_reviews, [:status])
    create index(:product_reviews, [:verified_purchase])

    # Region-specific pricing for geographic parameterized joins
    create table(:regional_pricing) do
      add :product_id, references(:parameterized_products, on_delete: :delete_all), null: false
      add :region_code, :string, null: false, size: 10  # US, EU, APAC, etc.
      add :currency, :string, null: false, size: 3      # USD, EUR, JPY, etc.
      add :price, :decimal, precision: 10, scale: 2
      add :tax_rate, :decimal, precision: 5, scale: 4, default: 0.0
      add :active, :boolean, default: true
      add :effective_date, :date
      add :expiry_date, :date

      timestamps(type: :utc_datetime)
    end

    create index(:regional_pricing, [:product_id])
    create index(:regional_pricing, [:region_code])
    create index(:regional_pricing, [:currency])
    create index(:regional_pricing, [:active])
    create unique_index(:regional_pricing, [:product_id, :region_code, :currency])
  end
end
