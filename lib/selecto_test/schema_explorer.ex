defmodule SelectoTest.SchemaExplorer do
  @moduledoc false

  defdelegate list_tables(), to: SelectoStudio.SchemaExplorer
  defdelegate preview_table(schema, table, limit \\ 30), to: SelectoStudio.SchemaExplorer

  defdelegate preview_table_page(schema, table, page, page_size, order_columns \\ []),
    to: SelectoStudio.SchemaExplorer

  defdelegate table_row_count(schema, table), to: SelectoStudio.SchemaExplorer
  defdelegate adjacent_joins(schema, table), to: SelectoStudio.SchemaExplorer
  defdelegate table_columns(schema, table), to: SelectoStudio.SchemaExplorer
  defdelegate table_columns_with_metadata(schema, table), to: SelectoStudio.SchemaExplorer
  defdelegate table_primary_keys(schema, table), to: SelectoStudio.SchemaExplorer
  defdelegate insert_row(schema, table, attrs), to: SelectoStudio.SchemaExplorer
  defdelegate update_row(schema, table, key_fields, attrs), to: SelectoStudio.SchemaExplorer
  defdelegate delete_row(schema, table, key_fields), to: SelectoStudio.SchemaExplorer
end
