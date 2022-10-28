defmodule SelectoTest.Repo do
  use Ecto.Repo,
    otp_app: :selecto_test,
    adapter: Ecto.Adapters.Postgres
end
