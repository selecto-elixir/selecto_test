defmodule SelectoTest.Repo.Migrations.CreateSavedViews do
  use Ecto.Migration

  def change do
    create table(:saved_views) do
      add :name, :string
      add :context, :string
      add :params, :map

      timestamps()
    end
  end
end
