defmodule SelectoTest.Store.Rental do
  use Ecto.Schema

  @primary_key {:rental_id, :id, autogenerate: true}

  schema "rental" do
    field :rental_date, :utc_datetime

    belongs_to :inventory, SelectoTest.Store.Inventory,
      foreign_key: :inventory_id,
      references: :inventory_id

    belongs_to :customer, SelectoTest.Store.Customer,
      foreign_key: :customer_id,
      references: :customer_id

    field :return_date, :utc_datetime
    belongs_to :staff, SelectoTest.Store.Staff, foreign_key: :staff_id, references: :staff_id
  end
end
