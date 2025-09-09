defmodule SelectoConeTestHelpers do
  @moduledoc """
  Helper functions for creating valid Selecto domains in tests.
  """
  
  def create_valid_domain(attrs \\ %{}) do
    defaults = %{
      source: %{
        source_table: "test_table",
        primary_key: :id,
        fields: [:id],
        columns: %{
          id: %{type: :integer}
        }
      },
      schemas: %{},
      name: "TestDomain"
    }
    
    Map.merge(defaults, attrs)
  end
  
  def add_schemas_key(domain) do
    domain
    |> Map.put_new(:schemas, %{})
    |> Map.put_new(:name, "Domain")
  end
end