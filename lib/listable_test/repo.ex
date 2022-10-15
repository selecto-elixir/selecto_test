defmodule ListableTest.Repo do
  use Ecto.Repo,
    otp_app: :listable_test,
    adapter: Ecto.Adapters.Postgres
end
