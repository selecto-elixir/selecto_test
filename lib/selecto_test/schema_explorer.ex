defmodule SelectoTest.SchemaExplorer do
  @moduledoc """
  Utilities for browsing Postgres tables and foreign-key relationships.
  """

  alias Ecto.Adapters.SQL
  alias SelectoTest.Repo

  @tables_sql """
  select table_schema, table_name
  from information_schema.tables
  where table_type = 'BASE TABLE'
    and table_schema not in ('pg_catalog', 'information_schema')
    and table_schema not like 'pg_toast%'
    and table_schema not like 'pg_temp_%'
  order by table_schema, table_name
  """

  @adjacent_joins_sql """
  select
    tc.constraint_name,
    fk.table_schema as from_schema,
    fk.table_name as from_table,
    fk.column_name as from_column,
    pk.table_schema as to_schema,
    pk.table_name as to_table,
    pk.column_name as to_column,
    fk.ordinal_position as ordinal_position
  from information_schema.table_constraints tc
  join information_schema.key_column_usage fk
    on fk.constraint_schema = tc.constraint_schema
   and fk.constraint_name = tc.constraint_name
  join information_schema.referential_constraints rc
    on rc.constraint_schema = tc.constraint_schema
   and rc.constraint_name = tc.constraint_name
  join information_schema.key_column_usage pk
    on pk.constraint_schema = rc.unique_constraint_schema
   and pk.constraint_name = rc.unique_constraint_name
   and pk.ordinal_position = fk.position_in_unique_constraint
  where tc.constraint_type = 'FOREIGN KEY'
    and (
      (fk.table_schema = $1 and fk.table_name = $2)
      or
      (pk.table_schema = $1 and pk.table_name = $2)
    )
  order by tc.constraint_name, fk.ordinal_position
  """

  @spec list_tables() :: {:ok, [map()]} | {:error, term()}
  def list_tables do
    with {:ok, %{rows: rows}} <- SQL.query(Repo, @tables_sql, []) do
      tables =
        Enum.map(rows, fn [schema, table] ->
          %{
            schema: schema,
            table: table,
            full_name: "#{schema}.#{table}"
          }
        end)

      {:ok, tables}
    end
  end

  @spec preview_table(binary(), binary(), pos_integer()) ::
          {:ok, %{columns: [binary()], rows: [map()]}} | {:error, term()}
  def preview_table(schema, table, limit \\ 30) when is_integer(limit) and limit > 0 do
    sql = """
    select *
    from #{quote_identifier(schema)}.#{quote_identifier(table)}
    limit $1
    """

    with {:ok, %{columns: columns, rows: rows}} <- SQL.query(Repo, sql, [limit]) do
      shaped_rows =
        Enum.map(rows, fn values ->
          columns
          |> Enum.zip(values)
          |> Enum.into(%{})
        end)

      {:ok, %{columns: columns, rows: shaped_rows}}
    end
  end

  @spec adjacent_joins(binary(), binary()) :: {:ok, [map()]} | {:error, term()}
  def adjacent_joins(schema, table) do
    with {:ok, %{rows: rows}} <- SQL.query(Repo, @adjacent_joins_sql, [schema, table]) do
      joins =
        rows
        |> Enum.map(fn [
                         constraint_name,
                         from_schema,
                         from_table,
                         from_column,
                         to_schema,
                         to_table,
                         to_column,
                         _position
                       ] ->
          %{
            constraint_name: constraint_name,
            from_schema: from_schema,
            from_table: from_table,
            to_schema: to_schema,
            to_table: to_table,
            column_pair: %{from_column: from_column, to_column: to_column}
          }
        end)
        |> Enum.group_by(fn join ->
          {join.constraint_name, join.from_schema, join.from_table, join.to_schema, join.to_table}
        end)
        |> Enum.map(fn {{constraint_name, from_schema, from_table, to_schema, to_table}, grouped} ->
          %{
            id: "#{constraint_name}|#{from_schema}.#{from_table}|#{to_schema}.#{to_table}",
            constraint_name: constraint_name,
            from_schema: from_schema,
            from_table: from_table,
            to_schema: to_schema,
            to_table: to_table,
            column_pairs: Enum.map(grouped, & &1.column_pair)
          }
        end)
        |> Enum.sort_by(
          &{&1.from_schema, &1.from_table, &1.to_schema, &1.to_table, &1.constraint_name}
        )

      {:ok, joins}
    end
  end

  defp quote_identifier(identifier) do
    escaped = String.replace(identifier, "\"", "\"\"")
    ~s("#{escaped}")
  end
end
