defmodule SelectoTest.Repo.Migrations.CreateEcommerceCategories do
  use Ecto.Migration

  def change do
    # Hierarchical categories with multiple hierarchy models
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :image_url, :string
      add :position, :integer, default: 0
      add :is_active, :boolean, default: true
      add :metadata, :map, default: %{}
      
      # Adjacency list model
      add :parent_id, references(:categories, type: :binary_id, on_delete: :nilify_all)
      
      # Materialized path model
      add :path, :string
      add :level, :integer, default: 0
      
      # Nested set model
      add :lft, :integer
      add :rgt, :integer
      
      timestamps()
    end
    
    create unique_index(:categories, [:slug])
    create index(:categories, [:parent_id])
    create index(:categories, [:path])
    create index(:categories, [:lft, :rgt])
    create index(:categories, [:is_active])
  end
end