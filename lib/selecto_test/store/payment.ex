defmodule SelectoTest.Store.Payment do
  use Ecto.Schema

  @primary_key {:payment_id, :id, autogenerate: true}

  schema "payment" do
    belongs_to :customer, SelectoTest.Store.Customer, foreign_key: :customer_id, references: :customer_id
    belongs_to :staff, SelectoTest.Store.Staff, foreign_key: :staff_id, references: :staff_id
    belongs_to :rental, SelectoTest.Store.Rental, foreign_key: :rental_id, references: :rental_id
    field :amount, :decimal
    field :payment_date, :utc_datetime
  end
end
