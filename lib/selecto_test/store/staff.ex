defmodule SelectoTest.Store.Staff do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:staff_id, :id, autogenerate: true}

  schema "staff" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    #has_one store
    has_one :address, SelectoTest.Store.Address, foreign_key: :address_id

    field :active, :boolean
    field :username, :string
    field :password, :string
    field :picture, :binary
  end

end
