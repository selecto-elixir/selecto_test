defmodule SelectoTest.Repo.Migrations.AddImdbExternalIds do
  use Ecto.Migration

  def change do
    alter table(:film) do
      add :imdb_tconst, :string
    end

    create unique_index(:film, [:imdb_tconst], name: :film_imdb_tconst_unique_idx)

    alter table(:actor) do
      add :imdb_nconst, :string
    end

    create unique_index(:actor, [:imdb_nconst], name: :actor_imdb_nconst_unique_idx)
  end
end
