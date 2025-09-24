defmodule SelectoTest.Repo.Migrations.CreateSavedViewConfigs do
  use Ecto.Migration

  def change do
    create table(:saved_view_configs) do
      add :name, :string, null: false
      add :context, :string, null: false
      # "detail", "aggregate", "graph"
      add :view_type, :string, null: false
      add :params, :map, null: false
      add :user_id, :string
      add :description, :text
      add :is_public, :boolean, default: false
      add :version, :integer, default: 1

      timestamps()
    end

    # Unique constraint for each view type per user
    create(
      unique_index(
        :saved_view_configs,
        ~w(name context view_type user_id)a,
        name: :saved_view_configs_unique_name_per_view_type
      )
    )

    # Index for querying by view type and context
    create(
      index(
        :saved_view_configs,
        ~w(view_type context)a,
        name: :saved_view_configs_view_type_context_idx
      )
    )

    # Index for user queries
    create(
      index(
        :saved_view_configs,
        [:user_id],
        name: :saved_view_configs_user_id_idx
      )
    )

    # Index for public views
    create(
      index(
        :saved_view_configs,
        [:is_public],
        name: :saved_view_configs_public_idx
      )
    )
  end
end
