defmodule SelectoTest.Store.Store do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:store_id, :id, autogenerate: true}

  schema "store" do
    # has_one :manager, SelectoTest.Store.Staff, foreign_key: :manager_staff_id, references: :staff_id
    has_one :address, SelectoTest.Store.Address, foreign_key: :address_id
  end
end
