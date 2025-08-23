defmodule SelectoTest.Repo.Migrations.AddFulltextToFilms do
  use Ecto.Migration

  def change do
    alter table(:film) do
      add :fulltext, :tsvector
    end

    # Add a GIN index for full-text search performance
    execute "CREATE INDEX film_fulltext_idx ON film USING gin(fulltext);"

    # Update existing records to populate the fulltext column
    execute """
    UPDATE film
    SET fulltext = to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, ''))
    WHERE fulltext IS NULL;
    """

    # Create a trigger to automatically update fulltext when title or description changes
    execute """
    CREATE OR REPLACE FUNCTION film_fulltext_trigger() RETURNS trigger AS $$
    BEGIN
      NEW.fulltext := to_tsvector('english', coalesce(NEW.title, '') || ' ' || coalesce(NEW.description, ''));
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute "CREATE TRIGGER film_fulltext_update BEFORE INSERT OR UPDATE ON film FOR EACH ROW EXECUTE FUNCTION film_fulltext_trigger();"
  end
end
