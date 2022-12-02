defmodule SelectoTest.Store.Address do
  use Ecto.Schema

  @primary_key {:address_id, :id, autogenerate: true}

  schema "address" do
    field :address, :string
    field :address2, :string
    field :district, :string
    field :postal_code, :string
    field :phone, :string

    has_one :city, SelectoTest.Store.City, foreign_key: :city_id
  end
end
