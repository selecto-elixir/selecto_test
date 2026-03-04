defmodule SelectoTest.Studio.ComponentsDomainBuilder do
  @moduledoc false

  alias SelectoTest.SchemaExplorer
  alias SelectoTest.Repo

  @default_select_count 6

  def build_selecto(payload) when is_map(payload) do
    with {:ok, {base_schema, base_table}} <- parse_full_table(Map.get(payload, "base_table")),
         {:ok, base_columns} <- SchemaExplorer.table_columns(base_schema, base_table),
         {:ok, selected_joins} <- normalize_selected_joins(Map.get(payload, "selected_joins", [])),
         {:ok, table_columns_by_full_name} <-
           fetch_table_columns(base_schema, base_table, selected_joins) do
      alias_by_join_id =
        selected_joins
        |> Enum.with_index(1)
        |> Map.new(fn {join, index} -> {join.id, String.to_atom("j#{index}")} end)

      alias_by_child_full_name =
        Map.new(selected_joins, fn join -> {join.child_full_name, alias_by_join_id[join.id]} end)

      base_full_name = "#{base_schema}.#{base_table}"

      associations_by_parent = build_associations_by_parent(selected_joins, alias_by_join_id)

      joins_tree =
        build_joins_tree(
          base_schema,
          base_table,
          selected_joins,
          alias_by_join_id,
          table_columns_by_full_name
        )

      root_source =
        build_source_schema(
          base_table,
          base_columns,
          Map.get(associations_by_parent, base_full_name, %{})
        )

      schemas =
        build_runtime_schemas(
          selected_joins,
          table_columns_by_full_name,
          associations_by_parent,
          base_full_name
        )

      domain = %{
        name: "StudioRuntime",
        source: root_source,
        schemas: schemas,
        joins: joins_tree
      }

      selecto = Selecto.configure(domain, Repo, validate: false)

      selecto =
        selecto
        |> apply_selected_columns(
          Map.get(payload, "selected_columns", []),
          base_table,
          alias_by_child_full_name
        )
        |> apply_filters(
          Map.get(payload, "filters", []),
          base_table,
          alias_by_child_full_name
        )
        |> apply_sort_rules(
          Map.get(payload, "sort_rules", []),
          get_in(payload, ["sort", "column_ref"]),
          get_in(payload, ["sort", "direction"]),
          base_table,
          alias_by_child_full_name
        )

      {:ok, selecto}
    end
  end

  def build_selecto(_payload), do: {:error, "Invalid components payload"}

  defp build_source_schema(source_table, columns, associations) do
    fields = Enum.map(columns, & &1.name)

    %{
      source_table: source_table,
      primary_key: infer_primary_key(source_table, fields),
      fields: fields,
      redact_fields: [],
      columns:
        Map.new(columns, fn column ->
          {column.name, %{type: to_selecto_type(column.data_type)}}
        end),
      associations: associations
    }
  end

  defp build_runtime_schemas(
         selected_joins,
         table_columns_by_full_name,
         associations_by_parent,
         base_full_name
       ) do
    selected_joins
    |> Enum.map(& &1.child_full_name)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn full_name, acc ->
      columns = Map.get(table_columns_by_full_name, full_name, [])

      source_table =
        case parse_full_table(full_name) do
          {:ok, {_schema, table}} -> table
          _ -> full_name
        end

      associations = Map.get(associations_by_parent, full_name, %{})
      schema = build_source_schema(source_table, columns, associations)

      Map.put(acc, full_name, schema)
    end)
    |> Map.delete(base_full_name)
  end

  defp build_associations_by_parent(selected_joins, alias_by_join_id) do
    selected_joins
    |> Enum.group_by(& &1.parent_full_name)
    |> Enum.into(%{}, fn {parent_full_name, joins} ->
      associations =
        joins
        |> Enum.reduce(%{}, fn join, acc ->
          join_alias = alias_by_join_id[join.id]
          association = %{queryable: join.child_full_name}
          Map.put(acc, join_alias, association)
        end)

      {parent_full_name, associations}
    end)
  end

  defp normalize_selected_joins(selected_joins) when is_list(selected_joins) do
    selected_joins
    |> Enum.reduce_while({:ok, []}, fn join_map, {:ok, acc} ->
      with {:ok, join} <- normalize_selected_join(join_map) do
        {:cont, {:ok, acc ++ [join]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_selected_joins(_), do: {:error, "Selected joins must be a list"}

  defp normalize_selected_join(join_map) when is_map(join_map) do
    id = map_get_string(join_map, "id")
    parent_schema = map_get_string(join_map, "parent_schema")
    parent_table = map_get_string(join_map, "parent_table")
    child_schema = map_get_string(join_map, "child_schema")
    child_table = map_get_string(join_map, "child_table")
    join_type = normalize_join_type(map_get_string(join_map, "join_type") || "left")

    on_pairs =
      map_get_list(join_map, "on")
      |> Enum.map(fn pair ->
        %{
          parent_column: map_get_string(pair, "parent_column"),
          child_column: map_get_string(pair, "child_column")
        }
      end)
      |> Enum.reject(fn pair -> is_nil(pair.parent_column) or is_nil(pair.child_column) end)

    if Enum.any?([id, parent_schema, parent_table, child_schema, child_table], &is_nil/1) or
         on_pairs == [] do
      {:error, "Invalid selected join payload"}
    else
      {:ok,
       %{
         id: id,
         join_type: join_type,
         parent_schema: parent_schema,
         parent_table: parent_table,
         child_schema: child_schema,
         child_table: child_table,
         parent_full_name: "#{parent_schema}.#{parent_table}",
         child_full_name: "#{child_schema}.#{child_table}",
         on: on_pairs
       }}
    end
  end

  defp normalize_selected_join(_), do: {:error, "Invalid selected join payload"}

  defp fetch_table_columns(base_schema, base_table, selected_joins) do
    table_refs =
      ["#{base_schema}.#{base_table}"] ++
        Enum.map(selected_joins, & &1.child_full_name) ++
        Enum.map(selected_joins, & &1.parent_full_name)

    table_refs
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, %{}}, fn full_name, {:ok, acc} ->
      with {:ok, {schema, table}} <- parse_full_table(full_name),
           {:ok, columns} <- SchemaExplorer.table_columns(schema, table) do
        {:cont, {:ok, Map.put(acc, full_name, columns)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp build_joins_tree(
         base_schema,
         base_table,
         selected_joins,
         alias_by_join_id,
         table_columns_by_full_name
       ) do
    base_full_name = "#{base_schema}.#{base_table}"
    joins_by_parent = Enum.group_by(selected_joins, & &1.parent_full_name)

    build_join_children(
      base_full_name,
      joins_by_parent,
      alias_by_join_id,
      table_columns_by_full_name
    )
  end

  defp build_join_children(
         parent_full_name,
         joins_by_parent,
         alias_by_join_id,
         table_columns_by_full_name
       ) do
    joins_by_parent
    |> Map.get(parent_full_name, [])
    |> Enum.reduce(%{}, fn join, acc ->
      join_alias = alias_by_join_id[join.id]
      child_columns = Map.get(table_columns_by_full_name, join.child_full_name, [])

      join_config = %{
        non_assoc: true,
        name: join.child_full_name,
        source: join.child_table,
        type: join_type_atom(join.join_type),
        owner_key: primary_join_owner_key(join.on),
        related_key: primary_join_related_key(join.on),
        on:
          Enum.map(join.on, fn pair ->
            %{left: pair.parent_column, right: pair.child_column}
          end),
        fields: build_custom_join_fields(join_alias, join.child_table, child_columns),
        joins:
          build_join_children(
            join.child_full_name,
            joins_by_parent,
            alias_by_join_id,
            table_columns_by_full_name
          )
      }

      Map.put(acc, join_alias, join_config)
    end)
  end

  defp primary_join_owner_key([first_pair | _rest]), do: first_pair.parent_column
  defp primary_join_owner_key([]), do: "id"

  defp primary_join_related_key([first_pair | _rest]), do: first_pair.child_column
  defp primary_join_related_key([]), do: "id"

  defp build_custom_join_fields(join_alias, child_table, child_columns) do
    Enum.reduce(child_columns, %{}, fn %{name: col_name, data_type: data_type}, acc ->
      field_config = %{
        colid: "#{join_alias}.#{col_name}",
        name: "#{child_table}.#{col_name}",
        field: col_name,
        requires_join: join_alias,
        type: to_selecto_type(data_type)
      }

      acc
      |> Map.put("#{join_alias}.#{col_name}", field_config)
      |> Map.put("#{join_alias}[#{col_name}]", field_config)
    end)
  end

  defp apply_selected_columns(selecto, selected_columns, base_table, alias_by_child_full_name) do
    available = available_field_names(selecto)

    selected =
      selected_columns
      |> normalize_string_list()
      |> Enum.map(&resolve_column_ref(&1, base_table, alias_by_child_full_name, available))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    selected =
      if selected == [] do
        available
        |> Enum.take(@default_select_count)
      else
        selected
      end

    Selecto.select(selecto, selected)
  end

  defp apply_filters(selecto, filters, base_table, alias_by_child_full_name) do
    available = available_field_names(selecto)

    filter_terms =
      filters
      |> normalize_filter_list()
      |> Enum.map(fn filter ->
        with field when not is_nil(field) <-
               resolve_column_ref(
                 filter.column_ref,
                 base_table,
                 alias_by_child_full_name,
                 available
               ) do
          filter_term(field, filter.operator, filter.value)
        end
      end)
      |> Enum.reject(&is_nil/1)

    if filter_terms == [] do
      selecto
    else
      Selecto.filter(selecto, filter_terms)
    end
  end

  defp apply_sort_rules(
         selecto,
         sort_rules,
         legacy_sort_column_ref,
         legacy_sort_direction,
         base_table,
         alias_by_child_full_name
       ) do
    available = available_field_names(selecto)

    sort_rules =
      sort_rules
      |> normalize_sort_list()

    sort_rules =
      if sort_rules == [] and is_binary(legacy_sort_column_ref) do
        [%{column_ref: legacy_sort_column_ref, direction: legacy_sort_direction || "asc"}]
      else
        sort_rules
      end

    order_by =
      sort_rules
      |> Enum.map(fn sort_rule ->
        with field when not is_nil(field) <-
               resolve_column_ref(
                 sort_rule.column_ref,
                 base_table,
                 alias_by_child_full_name,
                 available
               ) do
          {field, sort_direction_atom(sort_rule.direction)}
        end
      end)
      |> Enum.reject(&is_nil/1)

    if order_by == [] do
      selecto
    else
      Selecto.order_by(selecto, order_by)
    end
  end

  defp filter_term(_field, operator, _value) when operator in ["is_null"], do: nil

  defp filter_term(field, "eq", value), do: {field, value}
  defp filter_term(field, "neq", value), do: {field, {:not, value}}
  defp filter_term(field, "gt", value), do: {field, {:>, value}}
  defp filter_term(field, "gte", value), do: {field, {:>=, value}}
  defp filter_term(field, "lt", value), do: {field, {:<, value}}
  defp filter_term(field, "lte", value), do: {field, {:<=, value}}
  defp filter_term(field, "contains", value), do: {field, {:ilike, "%#{value}%"}}
  defp filter_term(field, "starts_with", value), do: {field, {:ilike, "#{value}%"}}
  defp filter_term(field, "ends_with", value), do: {field, {:ilike, "%#{value}"}}
  defp filter_term(field, "is_not_null", _value), do: {field, {:not, nil}}
  defp filter_term(field, _operator, value), do: {field, value}

  defp resolve_column_ref(column_ref, base_table, alias_by_child_full_name, available) do
    case parse_column_ref(column_ref) do
      {:ok, schema, table, column} ->
        table_key = "#{schema}.#{table}"

        candidates =
          if table == base_table do
            [column, "#{table}.#{column}"]
          else
            case Map.get(alias_by_child_full_name, table_key) do
              nil ->
                ["#{table}.#{column}"]

              join_alias ->
                ["#{join_alias}.#{column}", "#{join_alias}[#{column}]", "#{table}.#{column}"]
            end
          end

        Enum.find(candidates, &MapSet.member?(available, &1))

      :error ->
        nil
    end
  end

  defp available_field_names(selecto) do
    selecto
    |> Selecto.columns()
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> MapSet.new()
  end

  defp normalize_filter_list(filters) when is_list(filters) do
    Enum.map(filters, fn filter ->
      %{
        column_ref: map_get_string(filter, "column_ref"),
        operator: map_get_string(filter, "operator") || "eq",
        value: map_get_string(filter, "value") || ""
      }
    end)
  end

  defp normalize_filter_list(_), do: []

  defp normalize_sort_list(sort_rules) when is_list(sort_rules) do
    Enum.map(sort_rules, fn sort_rule ->
      %{
        column_ref: map_get_string(sort_rule, "column_ref"),
        direction: map_get_string(sort_rule, "direction") || "asc"
      }
    end)
    |> Enum.reject(fn sort_rule -> is_nil(sort_rule.column_ref) end)
  end

  defp normalize_sort_list(_), do: []

  defp parse_column_ref(column_ref) do
    case String.split(to_string(column_ref || ""), "|", parts: 3) do
      [schema, table, column] when schema != "" and table != "" and column != "" ->
        {:ok, schema, table, column}

      _ ->
        :error
    end
  end

  defp parse_full_table(full_table) do
    case String.split(to_string(full_table || ""), ".", parts: 2) do
      [schema, table] when schema != "" and table != "" -> {:ok, {schema, table}}
      _ -> {:error, "Invalid base table in components payload"}
    end
  end

  defp infer_primary_key(base_table, fields) do
    default = List.first(fields) || "id"
    by_id = Enum.find(fields, &(&1 == "id"))
    by_table = Enum.find(fields, &(&1 == "#{base_table}_id"))
    by_table || by_id || default
  end

  defp to_selecto_type(data_type) when is_binary(data_type) do
    case String.downcase(data_type) do
      "smallint" -> :integer
      "integer" -> :integer
      "bigint" -> :integer
      "numeric" -> :decimal
      "decimal" -> :decimal
      "real" -> :float
      "double precision" -> :float
      "boolean" -> :boolean
      "date" -> :date
      "timestamp without time zone" -> :datetime
      "timestamp with time zone" -> :datetime
      "time without time zone" -> :time
      "time with time zone" -> :time
      "text" -> :text
      "character varying" -> :string
      "character" -> :string
      _ -> :string
    end
  end

  defp to_selecto_type(_), do: :string

  defp sort_direction_atom(direction) do
    case String.downcase(to_string(direction || "asc")) do
      "desc" -> :desc
      _ -> :asc
    end
  end

  defp normalize_join_type(join_type) do
    case String.downcase(to_string(join_type || "left")) do
      "inner" -> "inner"
      _ -> "left"
    end
  end

  defp join_type_atom(join_type) do
    case normalize_join_type(join_type) do
      "inner" -> :inner
      _ -> :left
    end
  end

  defp normalize_string_list(values) when is_list(values) do
    values
    |> Enum.map(fn value ->
      value
      |> to_string()
      |> String.trim()
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_string_list(_), do: []

  defp map_get_string(map, key) when is_map(map) and is_binary(key) do
    value =
      case Map.fetch(map, key) do
        {:ok, value} ->
          value

        :error ->
          Enum.find_value(map, fn {k, v} -> if to_string(k) == key, do: v, else: nil end)
      end

    case value do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp map_get_string(_map, _key), do: nil

  defp map_get_list(map, key) when is_map(map) and is_binary(key) do
    value =
      case Map.fetch(map, key) do
        {:ok, value} ->
          value

        :error ->
          Enum.find_value(map, fn {k, v} -> if to_string(k) == key, do: v, else: nil end)
      end

    if is_list(value), do: value, else: []
  end

  defp map_get_list(_map, _key), do: []
end
