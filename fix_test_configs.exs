#!/usr/bin/env elixir

# Script to fix all test file configurations
defmodule FixTestConfigs do
  def run do
    test_files = [
      "test/docs_lateral_joins_examples_test.exs",
      "test/docs_parameterized_joins_examples_test.exs", 
      "test/docs_set_operations_examples_test.exs",
      "test/docs_subqueries_subfilters_examples_test.exs",
      "test/docs_subselects_examples_test.exs",
      "test/docs_window_functions_examples_test.exs"
    ]
    
    Enum.each(test_files, &fix_file/1)
    IO.puts("All test files updated!")
  end
  
  defp fix_file(file_path) do
    content = File.read!(file_path)
    
    # Find the module name
    module_name = Regex.run(~r/defmodule (\w+) do/, content) |> Enum.at(1)
    
    # Create new content with proper configuration
    new_content = """
defmodule #{module_name} do
  use ExUnit.Case, async: true
  
  alias Selecto.Builder.Sql
  
  # Helper function to configure test Selecto instance
  defp configure_test_selecto(table_name \\ "film") do
    domain = get_test_domain(table_name)
    connection = get_test_connection()
    Selecto.configure(domain, connection, validate: false)
  end
  
  defp get_test_domain(table_name) do
    %{
      name: "TestDomain",
      source: get_source_for_table(table_name),
      schemas: get_all_schemas(),
      joins: %{},
      settings: %{
        validate: false
      }
    }
  end
  
  defp get_test_connection do
    :test_connection
  end
  
  defp get_source_for_table(table_name) do
    # Generic table structure that works for all tables
    %{
      source_table: table_name,
      primary_key: String.to_atom(table_name <> "_id"),
      fields: get_fields_for_table(table_name),
      redact_fields: [],
      columns: get_columns_for_table(table_name),
      associations: %{}
    }
  end
  
  defp get_fields_for_table(_table_name) do
    # Return a comprehensive list of fields that covers most cases
    [:id, :name, :title, :description, :email, :customer_id, :order_id, :product_id,
     :employee_id, :film_id, :actor_id, :category_id, :payment_id, :rental_id,
     :first_name, :last_name, :amount, :total, :price, :quantity, :status,
     :created_at, :updated_at, :date, :order_date, :payment_date, :rental_date,
     :release_year, :rating, :special_features, :metadata, :settings, :preferences,
     :tags, :attributes, :specifications, :data, :config_json, :config_jsonb,
     :active, :department, :manager_id, :salary, :hire_date, :score, :revenue,
     :region, :country, :city, :address, :phone, :rental_rate, :replacement_cost,
     :length, :inventory_id, :staff_id, :store_id, :supplier_id, :category,
     :total_spent, :order_count, :product_name, :character_name, :billing_order,
     :published, :approved, :discontinued, :in_stock, :resolved, :level,
     :parent_id, :child_id, :user_id, :post_id, :comment_id, :review_id,
     :value, :metric, :event_time, :page_view, :session_id, :activity_count,
     :timestamp, :event_type, :event_name, :cohort_month, :order_month,
     :retention_rate, :conversion_rate, :avg_rating, :review_count, :snapshot_date,
     :location, :current_stock, :field_name, :old_value, :new_value, :changed_at,
     :changed_by, :supplier_id, :product_count, :avg_price, :price_rank, :line_number,
     :unit_price, :character_name, :billing_order, :commentable_type, :commentable_id,
     :friend_id, :tenant_id, :activity_count, :data_hash, :feature_count, :dimensions]
  end
  
  defp get_columns_for_table(_table_name) do
    # Return a map with all possible columns and their types
    %{
      id: %{type: :integer},
      name: %{type: :string},
      title: %{type: :string},
      description: %{type: :text},
      email: %{type: :string},
      customer_id: %{type: :integer},
      order_id: %{type: :integer},
      product_id: %{type: :integer},
      employee_id: %{type: :integer},
      film_id: %{type: :integer},
      actor_id: %{type: :integer},
      category_id: %{type: :integer},
      payment_id: %{type: :integer},
      rental_id: %{type: :integer},
      first_name: %{type: :string},
      last_name: %{type: :string},
      amount: %{type: :decimal},
      total: %{type: :decimal},
      price: %{type: :decimal},
      quantity: %{type: :integer},
      status: %{type: :string},
      created_at: %{type: :datetime},
      updated_at: %{type: :datetime},
      date: %{type: :date},
      order_date: %{type: :date},
      payment_date: %{type: :datetime},
      rental_date: %{type: :datetime},
      release_year: %{type: :integer},
      rating: %{type: :string},
      special_features: %{type: {:array, :string}},
      metadata: %{type: :map},
      settings: %{type: :map},
      preferences: %{type: :map},
      tags: %{type: {:array, :string}},
      attributes: %{type: :map},
      specifications: %{type: :map},
      data: %{type: :map},
      config_json: %{type: :map},
      config_jsonb: %{type: :map},
      active: %{type: :boolean},
      department: %{type: :string},
      manager_id: %{type: :integer},
      salary: %{type: :decimal},
      hire_date: %{type: :date},
      score: %{type: :decimal},
      revenue: %{type: :decimal},
      region: %{type: :string},
      country: %{type: :string},
      city: %{type: :string},
      address: %{type: :string},
      phone: %{type: :string},
      rental_rate: %{type: :decimal},
      replacement_cost: %{type: :decimal},
      length: %{type: :integer},
      inventory_id: %{type: :integer},
      staff_id: %{type: :integer},
      store_id: %{type: :integer},
      supplier_id: %{type: :integer},
      category: %{type: :string},
      total_spent: %{type: :decimal},
      order_count: %{type: :integer},
      product_name: %{type: :string},
      character_name: %{type: :string},
      billing_order: %{type: :integer},
      published: %{type: :boolean},
      approved: %{type: :boolean},
      discontinued: %{type: :boolean},
      in_stock: %{type: :boolean},
      resolved: %{type: :boolean},
      level: %{type: :integer},
      parent_id: %{type: :integer},
      child_id: %{type: :integer},
      user_id: %{type: :integer},
      post_id: %{type: :integer},
      comment_id: %{type: :integer},
      review_id: %{type: :integer},
      value: %{type: :decimal},
      metric: %{type: :string},
      event_time: %{type: :datetime},
      page_view: %{type: :string},
      session_id: %{type: :integer},
      activity_count: %{type: :integer},
      timestamp: %{type: :datetime},
      event_type: %{type: :string},
      event_name: %{type: :string},
      cohort_month: %{type: :date},
      order_month: %{type: :date},
      retention_rate: %{type: :decimal},
      conversion_rate: %{type: :decimal},
      avg_rating: %{type: :decimal},
      review_count: %{type: :integer},
      snapshot_date: %{type: :date},
      location: %{type: :string},
      current_stock: %{type: :integer},
      field_name: %{type: :string},
      old_value: %{type: :string},
      new_value: %{type: :string},
      changed_at: %{type: :datetime},
      changed_by: %{type: :string},
      product_count: %{type: :integer},
      avg_price: %{type: :decimal},
      price_rank: %{type: :integer},
      line_number: %{type: :integer},
      unit_price: %{type: :decimal},
      commentable_type: %{type: :string},
      commentable_id: %{type: :integer},
      friend_id: %{type: :integer},
      tenant_id: %{type: :integer},
      data_hash: %{type: :string},
      feature_count: %{type: :integer},
      dimensions: %{type: :integer}
    }
  end
  
  defp get_all_schemas do
    # Return all possible schemas referenced in tests
    %{}
  end

"""
    
    # Find where the tests start and append them
    test_start = Regex.run(~r/(  describe .+)/s, content, capture: :first)
    
    if test_start do
      test_content = Enum.at(test_start, 0)
      new_content = new_content <> "\n" <> test_content <> "\nend"
      File.write!(file_path, new_content)
      IO.puts("Fixed: #{file_path}")
    else
      IO.puts("Could not fix: #{file_path}")
    end
  end
end

FixTestConfigs.run()