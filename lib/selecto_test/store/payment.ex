defmodule SelectoTest.Store.Payment do
  use Ecto.Schema

  @primary_key {:payment_id, :id, autogenerate: true}

  schema "payment" do
    # has_one customer
    # has_one staff
    # has_one rental
    field :amount, :decimal
    field :payment_date, :utc_datetime
  end
end
