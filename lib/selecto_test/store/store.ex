defmodule SelectoTest.Store.Store do
  use Ecto.Schema
  @primary_key {:store_id, :id, autogenerate: true}

  schema "store" do
    # has_one :manager, SelectoTest.Store.Staff, foreign_key: :manager_staff_id, references: :staff_id
    has_one :address, SelectoTest.Store.Address, foreign_key: :address_id

    has_many :inventory, SelectoTest.Store.Inventory,
      references: :store_id,
      foreign_key: :store_id
  end
end
