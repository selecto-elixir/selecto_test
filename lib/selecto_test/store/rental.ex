defmodule SelectoTest.Store.Rental do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:rental_id, :id, autogenerate: true}

  schema "rental" do
    field :rental_date, :utc_datetime
    #has_one inventory
    #has_one customer
    field :return_date, :utc_datetime
    #has_one staff
  end

end
