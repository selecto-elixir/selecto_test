defmodule SelectoTest.Store.Staff do
  use Ecto.Schema

  @primary_key {:staff_id, :id, autogenerate: true}

  schema "staff" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string

    has_one :address, SelectoTest.Store.Address, foreign_key: :address_id
    belongs_to :store, SelectoTest.Store.Store, references: :store_id, foreign_key: :store_id

    field :active, :boolean
    field :username, :string
    field :password, :string
    field :picture, :binary
  end
end
