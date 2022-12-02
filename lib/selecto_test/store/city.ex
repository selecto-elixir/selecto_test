defmodule SelectoTest.Store.City do
  use Ecto.Schema

  @primary_key {:city_id, :id, autogenerate: true}

  schema "city" do
    field :city, :string

    has_one :country, SelectoTest.Store.Country, foreign_key: :country_id
  end
end
