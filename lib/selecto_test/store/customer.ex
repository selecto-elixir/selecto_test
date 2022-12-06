defmodule SelectoTest.Store.Customer do
  use Ecto.Schema

  @primary_key {:customer_id, :id, autogenerate: true}

  schema "customer" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :active, :integer
    field :activebool, :boolean
    has_one :store, SelectoTest.Store.Store, foreign_key: :store_id
    has_one :address, SelectoTest.Store.Address, foreign_key: :address_id

    has_many :rentals, SelectoTest.Store.Rental, foreign_key: :customer_id
  end
end
