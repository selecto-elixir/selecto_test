defmodule SelectoTestWeb.StudioLive do
  use SelectoTestWeb, :live_view

  alias SelectoTest.JoinConfigStore
  alias SelectoTest.SchemaExplorer

  @preview_limit 30

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Selecto Studio")
      |> assign(:tables, [])
      |> assign(:table_filter, "")
      |> assign(:selected_table, nil)
      |> assign(:preview_limit, @preview_limit)
      |> assign(:preview_columns, [])
      |> assign(:preview_rows, [])
      |> assign(:connected_tables, MapSet.new())
      |> assign(:join_cache, %{})
      |> assign(:available_joins, [])
      |> assign(:selected_joins, [])
      |> assign(:join_config_json, empty_join_config())
      |> assign(:selecto_join_config, empty_selecto_join_config())
      |> assign(:save_name, "")
      |> assign(:saved_configs, [])
      |> assign(:load_error, nil)
      |> assign(:preview_error, nil)
      |> assign(:join_error, nil)
      |> assign(:save_error, nil)
      |> refresh_saved_configs()

    {:ok, load_schema(socket)}
  end

  @impl true
  def handle_event("refresh_schema", _params, socket) do
    {:noreply, socket |> refresh_saved_configs() |> load_schema()}
  end

  @impl true
  def handle_event("filter_tables", %{"filters" => %{"q" => query}}, socket) do
    {:noreply, assign(socket, :table_filter, query)}
  end

  @impl true
  def handle_event("filter_tables", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_table", %{"schema" => schema, "table" => table_name}, socket) do
    selected_table =
      Enum.find(socket.assigns.tables, fn table ->
        table.schema == schema and table.table == table_name
      end)

    socket =
      case selected_table do
        nil -> socket
        table -> load_selected_table(socket, table)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_join", %{"id" => join_id}, socket) do
    {:noreply, add_join_by_id(socket, join_id)}
  end

  @impl true
  def handle_event("remove_join", %{"id" => join_id}, socket) do
    remaining_ids =
      socket.assigns.selected_joins
      |> Enum.reject(&(&1.id == join_id))
      |> Enum.map(& &1.id)

    {:noreply, rebuild_selected_joins(socket, remaining_ids)}
  end

  @impl true
  def handle_event("set_save_name", %{"save" => %{"name" => name}}, socket) do
    {:noreply, assign(socket, :save_name, name)}
  end

  @impl true
  def handle_event("set_save_name", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_config", _params, socket) do
    socket =
      if is_nil(socket.assigns.selected_table) do
        socket
        |> assign(:save_error, "Pick a base table before saving a config.")
        |> put_flash(:error, "No base table selected")
      else
        attrs = %{
          name: socket.assigns.save_name,
          base_table: full_table_name(socket.assigns.selected_table),
          selected_join_ids: Enum.map(socket.assigns.selected_joins, & &1.id),
          join_config_json: socket.assigns.join_config_json,
          selecto_join_config: socket.assigns.selecto_join_config
        }

        case JoinConfigStore.save_config(attrs) do
          {:ok, saved} ->
            socket
            |> assign(:save_error, nil)
            |> assign(:save_name, saved.name)
            |> put_flash(:info, "Saved #{saved.name}")
            |> refresh_saved_configs()

          {:error, reason} ->
            message = "Could not save config: #{inspect(reason)}"

            socket
            |> assign(:save_error, message)
            |> put_flash(:error, message)
        end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_saved_config", %{"id" => config_id}, socket) do
    socket =
      case JoinConfigStore.get_config(config_id) do
        {:ok, config} ->
          case find_table_by_full_name(socket.assigns.tables, config.base_table) do
            nil ->
              put_flash(socket, :error, "Saved base table #{config.base_table} is not available")

            table ->
              socket
              |> load_selected_table(table)
              |> rebuild_selected_joins(config.selected_join_ids)
              |> assign(:save_name, config.name)
              |> assign(:save_error, nil)
              |> put_flash(:info, "Loaded #{config.name}")
          end

        :error ->
          put_flash(socket, :error, "Saved config not found")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_saved_config", %{"id" => config_id}, socket) do
    :ok = JoinConfigStore.delete_config(config_id)

    socket =
      socket
      |> refresh_saved_configs()
      |> put_flash(:info, "Deleted saved config")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-[1500px] px-4 pb-8 pt-4 sm:px-6 lg:px-8">
      <div class="rounded-xl border border-gray-200 bg-white shadow-sm">
        <div class="border-b border-gray-100 px-6 py-5">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-gray-500">
                Schema Explorer
              </p>
              <h1 class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">Selecto Studio</h1>
              <p class="mt-2 text-sm text-gray-600">
                Browse any table, preview rows, walk adjacent relationships across multiple hops, and export joins.
              </p>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="refresh_schema"
                class="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                Refresh schema
              </button>

              <span
                :if={@selected_table}
                class="rounded-full border border-blue-200 bg-blue-50 px-3 py-1 text-xs font-semibold text-blue-700"
              >
                {@selected_table.full_name}
              </span>
            </div>
          </div>

          <p :if={@load_error} class="mt-3 text-sm text-rose-600">{@load_error}</p>
        </div>

        <div class="grid gap-4 p-4 lg:grid-cols-[18rem_minmax(0,1fr)_24rem]">
          <section class="rounded-xl border border-gray-200 bg-white p-4">
            <div class="mb-3 flex items-center justify-between">
              <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">Tables</h2>
              <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-700">
                {length(@tables)}
              </span>
            </div>

            <form id="table-filter-form" phx-change="filter_tables" class="mb-3">
              <input
                id="table-filter-input"
                class="block w-full rounded-lg border-gray-300 px-3 py-2 text-sm focus:border-blue-400 focus:ring-blue-200"
                type="text"
                name="filters[q]"
                value={@table_filter}
                placeholder="Filter by schema or table"
                autocomplete="off"
              />
            </form>

            <div class="max-h-[64vh] space-y-2 overflow-y-auto pr-1">
              <button
                :for={table <- filtered_tables(@tables, @table_filter)}
                id={"table-#{dom_id(table.full_name)}"}
                type="button"
                phx-click="select_table"
                phx-value-schema={table.schema}
                phx-value-table={table.table}
                class={[
                  "w-full rounded-lg border px-3 py-2 text-left transition",
                  selected_table?(table, @selected_table) && "border-blue-300 bg-blue-50",
                  not selected_table?(table, @selected_table) && "border-gray-200 hover:bg-gray-50"
                ]}
              >
                <div class="font-mono text-xs text-gray-500">{table.schema}</div>
                <div class="text-sm font-semibold text-gray-900">{table.table}</div>
              </button>

              <p :if={filtered_tables(@tables, @table_filter) == []} class="text-sm text-gray-600">
                No tables match your filter.
              </p>
            </div>
          </section>

          <section class="rounded-xl border border-gray-200 bg-white p-4">
            <div class="mb-3 flex items-center justify-between">
              <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
                Table Preview
              </h2>
              <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-700">
                first {@preview_limit} rows
              </span>
            </div>

            <p :if={@preview_error} class="mb-3 text-sm text-rose-600">{@preview_error}</p>

            <div
              :if={@selected_table == nil}
              class="rounded-lg border border-dashed border-gray-300 p-6 text-sm text-gray-600"
            >
              Pick a table to start exploring.
            </div>

            <div
              :if={@selected_table != nil and @preview_error == nil}
              class="max-h-[64vh] overflow-auto rounded-lg border border-gray-200"
            >
              <table class="min-w-full divide-y divide-gray-200 text-left text-xs">
                <thead class="sticky top-0 z-10 bg-gray-50">
                  <tr>
                    <th
                      :for={column <- @preview_columns}
                      class="whitespace-nowrap px-3 py-2 font-semibold text-gray-700"
                    >
                      {column}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <tr :if={@preview_rows == []}>
                    <td
                      colspan={column_count(@preview_columns)}
                      class="px-3 py-6 text-center text-sm text-gray-500"
                    >
                      No rows found.
                    </td>
                  </tr>

                  <tr :for={row <- @preview_rows}>
                    <td
                      :for={column <- @preview_columns}
                      class="max-w-[220px] px-3 py-2 align-top font-mono text-[11px] text-gray-700"
                    >
                      {format_cell(Map.get(row, column))}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section class="space-y-4">
            <div class="rounded-xl border border-gray-200 bg-white p-4">
              <div class="mb-3 flex items-center justify-between">
                <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
                  Available Joins
                </h2>
                <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-700">
                  {length(@available_joins)}
                </span>
              </div>

              <p :if={@join_error} class="mb-3 text-sm text-rose-600">{@join_error}</p>

              <div class="max-h-[26vh] space-y-2 overflow-y-auto pr-1">
                <div
                  :for={join <- @available_joins}
                  id={"available-join-#{dom_id(join.id)}"}
                  class="rounded-lg border border-gray-200 p-3"
                >
                  <p class="text-sm font-semibold text-gray-900">
                    {frontier_parent_label(join, @connected_tables)}
                    <span class="text-gray-400">-></span>
                    {frontier_child_label(join, @connected_tables)}
                  </p>
                  <p class="mt-1 text-xs text-gray-500">{join.constraint_name}</p>
                  <p class="mt-2 font-mono text-xs text-gray-600">
                    {frontier_condition(join, @connected_tables)}
                  </p>

                  <button
                    id={"add-join-#{dom_id(join.id)}"}
                    type="button"
                    phx-click="add_join"
                    phx-value-id={join.id}
                    class="mt-3 rounded-md bg-blue-600 px-2.5 py-1.5 text-xs font-semibold text-white hover:bg-blue-500"
                  >
                    Add join
                  </button>
                </div>

                <p :if={@available_joins == [] and @join_error == nil} class="text-sm text-gray-600">
                  No additional frontier joins available.
                </p>
              </div>
            </div>

            <div class="rounded-xl border border-gray-200 bg-white p-4">
              <div class="mb-3 flex items-center justify-between">
                <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
                  Selected Joins
                </h2>
                <span class="rounded-full bg-blue-50 px-2 py-0.5 text-xs font-semibold text-blue-700">
                  {length(@selected_joins)} selected
                </span>
              </div>

              <div class="mb-3 max-h-[20vh] space-y-2 overflow-y-auto pr-1">
                <div
                  :for={join <- @selected_joins}
                  id={"selected-join-#{dom_id(join.id)}"}
                  class="flex items-center justify-between rounded-lg border border-gray-200 px-3 py-2"
                >
                  <div>
                    <p class="text-sm font-medium text-gray-900">
                      {parent_full_name(join)}
                      <span class="text-gray-400">-></span>
                      {child_full_name(join)}
                    </p>
                    <p class="font-mono text-xs text-gray-600">{selected_join_condition(join)}</p>
                  </div>

                  <button
                    id={"remove-join-#{dom_id(join.id)}"}
                    type="button"
                    phx-click="remove_join"
                    phx-value-id={join.id}
                    class="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
                  >
                    Remove
                  </button>
                </div>
              </div>

              <p class="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-600">JSON</p>
              <textarea
                id="join-config-json"
                readonly
                class="h-36 w-full rounded-lg border-gray-300 font-mono text-xs text-gray-700 focus:border-blue-400 focus:ring-blue-200"
                value={@join_config_json}
              ></textarea>

              <p class="mb-1 mt-3 text-xs font-semibold uppercase tracking-wide text-gray-600">
                Selecto Joins Map
              </p>
              <textarea
                id="join-config-selecto"
                readonly
                class="h-36 w-full rounded-lg border-gray-300 font-mono text-xs text-gray-700 focus:border-blue-400 focus:ring-blue-200"
                value={@selecto_join_config}
              ></textarea>
            </div>

            <div class="rounded-xl border border-gray-200 bg-white p-4">
              <div class="mb-3 flex items-center justify-between">
                <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
                  Saved Configs
                </h2>
                <span class="rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700">
                  ETS
                </span>
              </div>

              <form
                id="save-config-form"
                phx-change="set_save_name"
                phx-submit="save_config"
                class="mb-3 space-y-2"
              >
                <input
                  id="save-config-name"
                  class="block w-full rounded-lg border-gray-300 px-3 py-2 text-sm focus:border-blue-400 focus:ring-blue-200"
                  type="text"
                  name="save[name]"
                  value={@save_name}
                  placeholder="Name this join config"
                />

                <button
                  type="submit"
                  class="w-full rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
                >
                  Save current config
                </button>
              </form>

              <p :if={@save_error} class="mb-2 text-sm text-rose-600">{@save_error}</p>

              <div class="max-h-[18vh] space-y-2 overflow-y-auto pr-1">
                <div
                  :for={saved <- @saved_configs}
                  id={"saved-config-#{dom_id(saved.id)}"}
                  class="rounded-lg border border-gray-200 px-3 py-2"
                >
                  <p class="text-sm font-semibold text-gray-900">{saved.name}</p>
                  <p class="text-xs text-gray-600">{saved.base_table}</p>
                  <p class="text-xs text-gray-500">{format_saved_at(saved.saved_at)}</p>

                  <div class="mt-2 flex gap-2">
                    <button
                      id={"load-saved-#{dom_id(saved.id)}"}
                      type="button"
                      phx-click="load_saved_config"
                      phx-value-id={saved.id}
                      class="rounded-md border border-blue-300 bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 hover:bg-blue-100"
                    >
                      Load
                    </button>

                    <button
                      id={"delete-saved-#{dom_id(saved.id)}"}
                      type="button"
                      phx-click="delete_saved_config"
                      phx-value-id={saved.id}
                      class="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
                    >
                      Delete
                    </button>
                  </div>
                </div>

                <p :if={@saved_configs == []} class="text-sm text-gray-600">Nothing saved yet.</p>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
    """
  end

  defp load_schema(socket) do
    case SchemaExplorer.list_tables() do
      {:ok, tables} ->
        selected_table = pick_selected_table(tables, socket.assigns.selected_table)

        socket
        |> assign(:tables, tables)
        |> assign(:load_error, nil)
        |> load_selected_table(selected_table)

      {:error, reason} ->
        socket
        |> assign(:tables, [])
        |> assign(:selected_table, nil)
        |> assign(:preview_columns, [])
        |> assign(:preview_rows, [])
        |> assign(:connected_tables, MapSet.new())
        |> assign(:join_cache, %{})
        |> assign(:available_joins, [])
        |> assign(:selected_joins, [])
        |> assign(:join_config_json, empty_join_config())
        |> assign(:selecto_join_config, empty_selecto_join_config())
        |> assign(:load_error, "Could not load database metadata: #{db_error(reason)}")
    end
  end

  defp load_selected_table(socket, nil) do
    socket
    |> assign(:selected_table, nil)
    |> assign(:preview_columns, [])
    |> assign(:preview_rows, [])
    |> assign(:connected_tables, MapSet.new())
    |> assign(:join_cache, %{})
    |> assign(:available_joins, [])
    |> assign(:selected_joins, [])
    |> assign(:preview_error, nil)
    |> assign(:join_error, nil)
    |> refresh_output_configs()
  end

  defp load_selected_table(socket, table) do
    {preview_columns, preview_rows, preview_error} =
      case SchemaExplorer.preview_table(table.schema, table.table, @preview_limit) do
        {:ok, %{columns: columns, rows: rows}} -> {columns, rows, nil}
        {:error, reason} -> {[], [], "Could not load rows: #{db_error(reason)}"}
      end

    connected_tables = MapSet.new([table_key(table.schema, table.table)])

    {join_cache, join_errors} = ensure_join_cache(%{}, connected_tables)
    available_joins = available_frontier_joins(connected_tables, join_cache, [])

    socket
    |> assign(:selected_table, table)
    |> assign(:preview_columns, preview_columns)
    |> assign(:preview_rows, preview_rows)
    |> assign(:connected_tables, connected_tables)
    |> assign(:join_cache, join_cache)
    |> assign(:available_joins, available_joins)
    |> assign(:selected_joins, [])
    |> assign(:preview_error, preview_error)
    |> assign(:join_error, join_error_message(join_errors))
    |> refresh_output_configs()
  end

  defp add_join_by_id(socket, join_id) do
    case Enum.find(socket.assigns.available_joins, &(&1.id == join_id)) do
      nil ->
        socket

      join ->
        case join_frontier_endpoints(join, socket.assigns.connected_tables) do
          {:ok, parent_key, child_key} ->
            selected_join = build_selected_join(join, parent_key, child_key)
            selected_joins = socket.assigns.selected_joins ++ [selected_join]
            connected_tables = MapSet.put(socket.assigns.connected_tables, child_key)

            {join_cache, join_errors} =
              ensure_join_cache(socket.assigns.join_cache, connected_tables)

            available_joins =
              available_frontier_joins(connected_tables, join_cache, selected_joins)

            socket
            |> assign(:selected_joins, selected_joins)
            |> assign(:connected_tables, connected_tables)
            |> assign(:join_cache, join_cache)
            |> assign(:available_joins, available_joins)
            |> assign(:join_error, join_error_message(join_errors))
            |> refresh_output_configs()

          :error ->
            socket
        end
    end
  end

  defp rebuild_selected_joins(socket, join_ids) do
    case socket.assigns.selected_table do
      nil ->
        socket

      table ->
        base_key = table_key(table.schema, table.table)
        connected_tables = MapSet.new([base_key])
        {join_cache, join_errors} = ensure_join_cache(socket.assigns.join_cache, connected_tables)
        available_joins = available_frontier_joins(connected_tables, join_cache, [])

        base_socket =
          socket
          |> assign(:connected_tables, connected_tables)
          |> assign(:join_cache, join_cache)
          |> assign(:available_joins, available_joins)
          |> assign(:selected_joins, [])
          |> assign(:join_error, join_error_message(join_errors))
          |> refresh_output_configs()

        Enum.reduce(join_ids, base_socket, fn join_id, acc_socket ->
          add_join_by_id(acc_socket, join_id)
        end)
    end
  end

  defp ensure_join_cache(join_cache, connected_tables) do
    Enum.reduce(connected_tables, {join_cache, []}, fn table_key, {cache, errors} ->
      if Map.has_key?(cache, table_key) do
        {cache, errors}
      else
        {schema, table} = table_key

        case SchemaExplorer.adjacent_joins(schema, table) do
          {:ok, joins} ->
            {Map.put(cache, table_key, joins), errors}

          {:error, reason} ->
            {Map.put(cache, table_key, []), [db_error(reason) | errors]}
        end
      end
    end)
  end

  defp available_frontier_joins(connected_tables, join_cache, selected_joins) do
    selected_ids = MapSet.new(Enum.map(selected_joins, & &1.id))

    join_cache
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq_by(& &1.id)
    |> Enum.reject(&MapSet.member?(selected_ids, &1.id))
    |> Enum.filter(fn join ->
      match?({:ok, _parent, _child}, join_frontier_endpoints(join, connected_tables))
    end)
    |> Enum.sort_by(fn join ->
      case join_frontier_endpoints(join, connected_tables) do
        {:ok, parent_key, child_key} ->
          {table_key_to_string(parent_key), table_key_to_string(child_key), join.constraint_name}

        :error ->
          {"", "", join.constraint_name}
      end
    end)
  end

  defp build_selected_join(join, parent_key, child_key) do
    {parent_schema, parent_table} = parent_key
    {child_schema, child_table} = child_key

    %{
      id: join.id,
      constraint_name: join.constraint_name,
      from_schema: join.from_schema,
      from_table: join.from_table,
      to_schema: join.to_schema,
      to_table: join.to_table,
      parent_schema: parent_schema,
      parent_table: parent_table,
      child_schema: child_schema,
      child_table: child_table,
      on: directed_pairs_for_parent(join, parent_key)
    }
  end

  defp directed_pairs_for_parent(join, parent_key) do
    from_key = join_from_key(join)

    if parent_key == from_key do
      Enum.map(join.column_pairs, fn pair ->
        %{parent_column: pair.from_column, child_column: pair.to_column}
      end)
    else
      Enum.map(join.column_pairs, fn pair ->
        %{parent_column: pair.to_column, child_column: pair.from_column}
      end)
    end
  end

  defp join_frontier_endpoints(join, connected_tables) do
    from_key = join_from_key(join)
    to_key = join_to_key(join)

    from_connected = MapSet.member?(connected_tables, from_key)
    to_connected = MapSet.member?(connected_tables, to_key)

    cond do
      from_connected and not to_connected -> {:ok, from_key, to_key}
      to_connected and not from_connected -> {:ok, to_key, from_key}
      true -> :error
    end
  end

  defp join_from_key(join), do: table_key(join.from_schema, join.from_table)
  defp join_to_key(join), do: table_key(join.to_schema, join.to_table)

  defp refresh_output_configs(socket) do
    socket
    |> assign(
      :join_config_json,
      build_join_config(socket.assigns.selected_table, socket.assigns.selected_joins)
    )
    |> assign(
      :selecto_join_config,
      build_selecto_join_config(socket.assigns.selected_table, socket.assigns.selected_joins)
    )
  end

  defp build_join_config(selected_table, selected_joins) do
    %{
      base_table: full_table_name(selected_table),
      joins:
        Enum.map(selected_joins, fn join ->
          %{
            id: join.id,
            constraint: join.constraint_name,
            parent: parent_full_name(join),
            child: child_full_name(join),
            on: join.on
          }
        end)
    }
    |> Jason.encode!(pretty: true)
  end

  defp build_selecto_join_config(nil, _selected_joins), do: empty_selecto_join_config()

  defp build_selecto_join_config(selected_table, selected_joins) do
    base_table = full_table_name(selected_table)
    joins_by_parent = Enum.group_by(selected_joins, &parent_full_name/1)

    %{
      base_table: base_table,
      joins: build_selecto_join_tree(base_table, joins_by_parent)
    }
    |> inspect(pretty: true, limit: :infinity, width: 100)
  end

  defp build_selecto_join_tree(parent_full_name, joins_by_parent) do
    joins_by_parent
    |> Map.get(parent_full_name, [])
    |> Enum.sort_by(&{&1.child_schema, &1.child_table, &1.constraint_name})
    |> Enum.reduce(%{}, fn join, acc ->
      child_full_name = child_full_name(join)

      Map.put(acc, selecto_join_key(join), %{
        name: child_full_name,
        type: :left,
        source: parent_full_name,
        source_columns: Enum.map(join.on, & &1.parent_column),
        target: child_full_name,
        target_columns: Enum.map(join.on, & &1.child_column),
        joins: build_selecto_join_tree(child_full_name, joins_by_parent)
      })
    end)
  end

  defp selecto_join_key(join) do
    "#{join.child_table}_#{join.constraint_name}"
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end

  defp refresh_saved_configs(socket) do
    assign(socket, :saved_configs, JoinConfigStore.list_configs())
  end

  defp pick_selected_table(tables, nil), do: List.first(tables)

  defp pick_selected_table(tables, selected_table) do
    Enum.find(tables, &selected_table?(&1, selected_table)) || List.first(tables)
  end

  defp filtered_tables(tables, query) do
    normalized_query =
      query
      |> String.trim()
      |> String.downcase()

    if normalized_query == "" do
      tables
    else
      Enum.filter(tables, fn table ->
        String.contains?(String.downcase(table.full_name), normalized_query)
      end)
    end
  end

  defp selected_table?(_table, nil), do: false

  defp selected_table?(table, selected_table) do
    table.schema == selected_table.schema and table.table == selected_table.table
  end

  defp parent_full_name(join), do: "#{join.parent_schema}.#{join.parent_table}"
  defp child_full_name(join), do: "#{join.child_schema}.#{join.child_table}"

  defp table_key(schema, table), do: {schema, table}
  defp table_key_to_string({schema, table}), do: "#{schema}.#{table}"

  defp frontier_parent_label(join, connected_tables) do
    case join_frontier_endpoints(join, connected_tables) do
      {:ok, parent_key, _child_key} -> table_key_to_string(parent_key)
      :error -> table_key_to_string(join_from_key(join))
    end
  end

  defp frontier_child_label(join, connected_tables) do
    case join_frontier_endpoints(join, connected_tables) do
      {:ok, _parent_key, child_key} -> table_key_to_string(child_key)
      :error -> table_key_to_string(join_to_key(join))
    end
  end

  defp frontier_condition(join, connected_tables) do
    case join_frontier_endpoints(join, connected_tables) do
      {:ok, parent_key, _child_key} ->
        directed_pairs_for_parent(join, parent_key)
        |> Enum.map(fn pair -> "#{pair.parent_column} = #{pair.child_column}" end)
        |> Enum.join(" and ")

      :error ->
        join.column_pairs
        |> Enum.map(fn pair -> "#{pair.from_column} = #{pair.to_column}" end)
        |> Enum.join(" and ")
    end
  end

  defp selected_join_condition(join) do
    join.on
    |> Enum.map(fn pair -> "#{pair.parent_column} = #{pair.child_column}" end)
    |> Enum.join(" and ")
  end

  defp find_table_by_full_name(_tables, nil), do: nil

  defp find_table_by_full_name(tables, full_name) do
    Enum.find(tables, &(&1.full_name == full_name))
  end

  defp full_table_name(nil), do: nil
  defp full_table_name(table), do: "#{table.schema}.#{table.table}"

  defp empty_join_config do
    Jason.encode!(%{base_table: nil, joins: []}, pretty: true)
  end

  defp empty_selecto_join_config do
    inspect(%{base_table: nil, joins: %{}}, pretty: true, limit: :infinity, width: 100)
  end

  defp format_cell(nil), do: "NULL"

  defp format_cell(value) when is_binary(value) do
    if String.length(value) > 120 do
      String.slice(value, 0, 117) <> "..."
    else
      value
    end
  end

  defp format_cell(value), do: inspect(value, printable_limit: 120)

  defp column_count(columns), do: max(length(columns), 1)

  defp join_error_message([]), do: nil

  defp join_error_message(errors) do
    messages = errors |> Enum.reverse() |> Enum.uniq() |> Enum.join(" | ")
    "Some relationships could not be loaded: #{messages}"
  end

  defp format_saved_at(%DateTime{} = saved_at) do
    Calendar.strftime(saved_at, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_saved_at(_), do: ""

  defp dom_id(value) when is_binary(value) do
    normalized =
      value
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    if normalized == "", do: "item", else: normalized
  end

  defp db_error(%{message: message}) when is_binary(message), do: message
  defp db_error(error), do: inspect(error)
end
