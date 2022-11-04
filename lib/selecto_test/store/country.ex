defmodule SelectoTest.Store.Country do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:country_id, :id, autogenerate: true}

  schema "country" do
    field :country, :string
  end

end
