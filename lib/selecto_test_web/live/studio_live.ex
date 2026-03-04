defmodule SelectoTestWeb.StudioLive do
  use SelectoTestWeb, :live_view

  alias Ecto.Adapters.SQL
  alias SelectoTest.JoinConfigStore
  alias SelectoTest.Repo
  alias SelectoTest.SchemaExplorer

  @preview_limit 30
  @query_page_size 25
  @max_query_page_size 200
  @query_timeout_ms 8_000
  @max_csv_export_rows 10_000
  @default_column_count 6

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
      |> assign(:column_cache, %{})
      |> assign(:available_joins, [])
      |> assign(:selected_joins, [])
      |> assign(:available_columns, [])
      |> assign(:selected_columns, [])
      |> assign(:filters, [])
      |> assign(:filter_seq, 0)
      |> assign(:join_config_json, empty_join_config())
      |> assign(:selecto_join_config, empty_selecto_join_config())
      |> assign(:query_columns, [])
      |> assign(:query_rows, [])
      |> assign(:query_sql, nil)
      |> assign(:query_error, nil)
      |> assign(:query_builder_error, nil)
      |> assign(:query_page_size, @query_page_size)
      |> assign(:max_query_page_size, @max_query_page_size)
      |> assign(:query_page, 1)
      |> assign(:query_total_rows, 0)
      |> assign(:query_total_pages, 0)
      |> assign(:sort_column_ref, nil)
      |> assign(:sort_direction, "asc")
      |> assign(:query_running, false)
      |> assign(:import_config_json, "")
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
  def handle_event("update_query", %{"query" => query_params}, socket) do
    selected_columns = normalize_selected_columns(Map.get(query_params, "selected_columns"))
    filter_params = Map.get(query_params, "filters", %{})
    sort_column_ref = Map.get(query_params, "sort_column_ref")
    sort_direction = Map.get(query_params, "sort_direction", "asc")
    page_size = Map.get(query_params, "page_size")

    filters =
      socket.assigns.filters
      |> Enum.map(fn filter ->
        params = Map.get(filter_params, filter.id, %{})

        %{
          filter
          | column_ref: Map.get(params, "column_ref", filter.column_ref),
            operator: Map.get(params, "operator", filter.operator),
            value: Map.get(params, "value", filter.value)
        }
      end)

    socket =
      socket
      |> cancel_async(:studio_query)
      |> assign(:selected_columns, selected_columns)
      |> assign(:filters, filters)
      |> assign(:sort_column_ref, sort_column_ref)
      |> assign(:sort_direction, sort_direction)
      |> assign(:query_page_size, page_size)
      |> assign(:query_page, 1)
      |> assign(:query_running, false)
      |> sanitize_query_state()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_query", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_filter", _params, socket) do
    case socket.assigns.available_columns do
      [] ->
        {:noreply, put_flash(socket, :error, "Connect at least one table with columns first")}

      _columns ->
        next_seq = socket.assigns.filter_seq + 1

        new_filter = %{
          id: "f#{next_seq}",
          column_ref: List.first(socket.assigns.available_columns).id,
          operator: "eq",
          value: ""
        }

        socket =
          socket
          |> cancel_async(:studio_query)
          |> assign(:filter_seq, next_seq)
          |> assign(:filters, socket.assigns.filters ++ [new_filter])
          |> assign(:query_page, 1)
          |> assign(:query_running, false)
          |> sanitize_query_state()

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_filter", %{"id" => filter_id}, socket) do
    filters = Enum.reject(socket.assigns.filters, &(&1.id == filter_id))

    {:noreply,
     socket
     |> cancel_async(:studio_query)
     |> assign(:filters, filters)
     |> assign(:query_page, 1)
     |> assign(:query_running, false)
     |> sanitize_query_state()}
  end

  @impl true
  def handle_event("run_query", _params, socket) do
    {:noreply, start_query_run(socket)}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    next_page = max(socket.assigns.query_page - 1, 1)

    socket =
      if next_page == socket.assigns.query_page do
        socket
      else
        socket
        |> assign(:query_page, next_page)
        |> start_query_run()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    max_page = max(socket.assigns.query_total_pages, 1)
    next_page = min(socket.assigns.query_page + 1, max_page)

    socket =
      if next_page == socket.assigns.query_page do
        socket
      else
        socket
        |> assign(:query_page, next_page)
        |> start_query_run()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_query", _params, socket) do
    {:noreply, reset_query_state(socket)}
  end

  @impl true
  def handle_event("cancel_query", _params, socket) do
    socket =
      socket
      |> cancel_async(:studio_query)
      |> assign(:query_running, false)
      |> put_flash(:info, "Cancelled query")

    {:noreply, socket}
  end

  @impl true
  def handle_event("download_csv", %{"scope" => scope}, socket) do
    socket =
      case download_csv(socket, scope) do
        {:ok, socket} -> socket
        {:error, message, socket} -> put_flash(socket, :error, message)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_import_config", %{"import" => %{"json" => json}}, socket) do
    {:noreply, assign(socket, :import_config_json, json)}
  end

  @impl true
  def handle_event("set_import_config", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("import_config", _params, socket) do
    socket =
      case parse_import_config(socket.assigns.import_config_json) do
        {:ok, imported} ->
          case apply_imported_config(socket, imported) do
            {:ok, next_socket} ->
              next_socket
              |> put_flash(:info, "Imported studio config")

            {:error, message, next_socket} ->
              next_socket
              |> put_flash(:error, message)
          end

        {:error, message} ->
          put_flash(socket, :error, message)
      end

    {:noreply, socket}
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
          selected_columns: socket.assigns.selected_columns,
          filters: socket.assigns.filters,
          sort_column_ref: socket.assigns.sort_column_ref,
          sort_direction: socket.assigns.sort_direction,
          query_page_size: socket.assigns.query_page_size,
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
              selected_columns =
                normalize_selected_columns(Map.get(config, :selected_columns, []))

              filters = normalize_saved_filters(Map.get(config, :filters, []))
              filter_seq = next_filter_seq(filters)
              sort_column_ref = Map.get(config, :sort_column_ref)
              sort_direction = normalize_sort_direction(Map.get(config, :sort_direction, "asc"))
              query_page_size = normalize_query_page_size(Map.get(config, :query_page_size))

              socket
              |> load_selected_table(table)
              |> rebuild_selected_joins(Map.get(config, :selected_join_ids, []))
              |> assign(:selected_columns, selected_columns)
              |> assign(:filters, filters)
              |> assign(:filter_seq, filter_seq)
              |> assign(:sort_column_ref, sort_column_ref)
              |> assign(:sort_direction, sort_direction)
              |> assign(:query_page_size, query_page_size)
              |> sanitize_query_state()
              |> assign(:query_columns, [])
              |> assign(:query_rows, [])
              |> assign(:query_sql, nil)
              |> assign(:query_error, nil)
              |> assign(:query_page, 1)
              |> assign(:query_total_rows, 0)
              |> assign(:query_total_pages, 0)
              |> assign(:query_running, false)
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
  def handle_async(:studio_query, {:ok, {:ok, result}}, socket) do
    socket =
      socket
      |> assign(:query_columns, result.columns)
      |> assign(:query_rows, result.rows)
      |> assign(:query_sql, result.sql)
      |> assign(:query_error, nil)
      |> assign(:query_page, result.page)
      |> assign(:query_total_rows, result.total_rows)
      |> assign(:query_total_pages, result.total_pages)
      |> assign(:query_running, false)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:studio_query, {:ok, {:error, message}}, socket) do
    socket =
      socket
      |> assign(:query_rows, [])
      |> assign(:query_columns, [])
      |> assign(:query_total_rows, 0)
      |> assign(:query_total_pages, 0)
      |> assign(:query_error, db_error(message))
      |> assign(:query_running, false)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:studio_query, {:exit, {:shutdown, :cancel}}, socket) do
    {:noreply, assign(socket, :query_running, false)}
  end

  @impl true
  def handle_async(:studio_query, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:query_running, false)
      |> assign(:query_error, "Query failed: #{inspect(reason)}")

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

              <p class="mb-1 mt-3 text-xs font-semibold uppercase tracking-wide text-gray-600">
                Selecto Handoff Snippet
              </p>
              <textarea
                id="selecto-handoff-snippet"
                readonly
                class="h-44 w-full rounded-lg border-gray-300 font-mono text-xs text-gray-700 focus:border-blue-400 focus:ring-blue-200"
                value={
                  build_selecto_handoff_snippet(
                    @selected_table,
                    @selected_columns,
                    @filters,
                    @sort_column_ref,
                    @sort_direction
                  )
                }
              ></textarea>
            </div>

            <div class="rounded-xl border border-gray-200 bg-white p-4">
              <div class="mb-3 flex items-center justify-between">
                <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
                  Query Builder
                </h2>
                <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-700">
                  {length(@selected_columns)} cols
                </span>
              </div>

              <p :if={@query_builder_error} class="mb-2 text-sm text-rose-600">
                {@query_builder_error}
              </p>

              <form
                id="query-builder-form"
                phx-change="update_query"
                phx-submit="run_query"
                class="space-y-3"
              >
                <div>
                  <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-gray-600">
                    Columns
                  </p>

                  <div class="max-h-[16vh] space-y-2 overflow-y-auto rounded-lg border border-gray-200 p-2">
                    <div :for={group <- grouped_available_columns(@available_columns)}>
                      <p class="mb-1 text-xs font-semibold text-gray-500">{group.table_label}</p>
                      <label
                        :for={column <- group.columns}
                        class="flex items-center gap-2 py-0.5 text-xs text-gray-700"
                      >
                        <input
                          id={"query-col-#{dom_id(column.id)}"}
                          type="checkbox"
                          name="query[selected_columns][]"
                          value={column.id}
                          checked={column_selected?(@selected_columns, column.id)}
                          class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                        />
                        <span class="font-mono">{column.column}</span>
                        <span class="text-gray-400">({column.data_type})</span>
                      </label>
                    </div>

                    <p :if={@available_columns == []} class="text-xs text-gray-500">
                      No columns available yet. Pick a table first.
                    </p>
                  </div>
                </div>

                <div>
                  <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-gray-600">Sort</p>

                  <div class="grid grid-cols-[1fr_auto] gap-2 rounded-lg border border-gray-200 p-2">
                    <select
                      id="sort-column-select"
                      name="query[sort_column_ref]"
                      class="rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200"
                    >
                      <option
                        :for={column <- @available_columns}
                        value={column.id}
                        selected={column.id == @sort_column_ref}
                      >
                        {column.label}
                      </option>
                    </select>

                    <select
                      id="sort-direction-select"
                      name="query[sort_direction]"
                      class="rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200"
                    >
                      <option value="asc" selected={@sort_direction == "asc"}>asc</option>
                      <option value="desc" selected={@sort_direction == "desc"}>desc</option>
                    </select>
                  </div>
                </div>

                <div>
                  <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-gray-600">
                    Page size
                  </p>
                  <select
                    id="query-page-size"
                    name="query[page_size]"
                    class="w-full rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200"
                  >
                    <option
                      :for={size <- query_page_size_options()}
                      value={size}
                      selected={@query_page_size == size}
                    >
                      {size}
                    </option>
                  </select>
                  <p class="mt-1 text-[11px] text-gray-500">Max page size: {@max_query_page_size}</p>
                </div>

                <div>
                  <div class="mb-2 flex items-center justify-between">
                    <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">Filters</p>
                    <button
                      id="add-filter-button"
                      type="button"
                      phx-click="add_filter"
                      class="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
                    >
                      Add filter
                    </button>
                  </div>

                  <div class="max-h-[20vh] space-y-2 overflow-y-auto">
                    <div
                      :for={filter <- @filters}
                      id={"filter-row-#{filter.id}"}
                      class="rounded-lg border border-gray-200 p-2"
                    >
                      <div class="grid gap-2">
                        <select
                          id={"filter-column-#{filter.id}"}
                          name={"query[filters][#{filter.id}][column_ref]"}
                          class="rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200"
                        >
                          <option
                            :for={column <- @available_columns}
                            value={column.id}
                            selected={column.id == filter.column_ref}
                          >
                            {column.label}
                          </option>
                        </select>

                        <div class="grid grid-cols-[1fr_auto] gap-2">
                          <select
                            id={"filter-operator-#{filter.id}"}
                            name={"query[filters][#{filter.id}][operator]"}
                            class="rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200"
                          >
                            <option
                              :for={operator <- filter_operator_options(filter, @available_columns)}
                              value={operator.value}
                              selected={operator.value == filter.operator}
                            >
                              {operator.label}
                            </option>
                          </select>

                          <button
                            id={"remove-filter-#{filter.id}"}
                            type="button"
                            phx-click="remove_filter"
                            phx-value-id={filter.id}
                            class="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
                          >
                            Remove
                          </button>
                        </div>

                        <div>
                          <%= case filter_input_kind(filter, @available_columns) do %>
                            <% :boolean -> %>
                              <select
                                id={"filter-value-#{filter.id}"}
                                name={"query[filters][#{filter.id}][value]"}
                                disabled={not operator_requires_value?(filter.operator)}
                                class="w-full rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200 disabled:bg-gray-100"
                              >
                                <option value="true" selected={filter.value in ["true", "1"]}>
                                  true
                                </option>
                                <option value="false" selected={filter.value in ["false", "0"]}>
                                  false
                                </option>
                              </select>
                            <% :number -> %>
                              <input
                                id={"filter-value-#{filter.id}"}
                                type="number"
                                step="any"
                                name={"query[filters][#{filter.id}][value]"}
                                value={filter.value}
                                disabled={not operator_requires_value?(filter.operator)}
                                placeholder="Numeric value"
                                class="w-full rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200 disabled:bg-gray-100"
                              />
                            <% :date -> %>
                              <input
                                id={"filter-value-#{filter.id}"}
                                type="date"
                                name={"query[filters][#{filter.id}][value]"}
                                value={filter.value}
                                disabled={not operator_requires_value?(filter.operator)}
                                class="w-full rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200 disabled:bg-gray-100"
                              />
                            <% :datetime -> %>
                              <input
                                id={"filter-value-#{filter.id}"}
                                type="datetime-local"
                                name={"query[filters][#{filter.id}][value]"}
                                value={normalize_datetime_value_for_input(filter.value)}
                                disabled={not operator_requires_value?(filter.operator)}
                                class="w-full rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200 disabled:bg-gray-100"
                              />
                            <% :time -> %>
                              <input
                                id={"filter-value-#{filter.id}"}
                                type="time"
                                name={"query[filters][#{filter.id}][value]"}
                                value={normalize_time_value_for_input(filter.value)}
                                disabled={not operator_requires_value?(filter.operator)}
                                class="w-full rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200 disabled:bg-gray-100"
                              />
                            <% _ -> %>
                              <input
                                id={"filter-value-#{filter.id}"}
                                type="text"
                                name={"query[filters][#{filter.id}][value]"}
                                value={filter.value}
                                disabled={not operator_requires_value?(filter.operator)}
                                placeholder="Filter value"
                                class="w-full rounded-md border-gray-300 px-2 py-1 text-xs focus:border-blue-400 focus:ring-blue-200 disabled:bg-gray-100"
                              />
                          <% end %>
                        </div>
                      </div>
                    </div>

                    <p :if={@filters == []} class="text-xs text-gray-500">
                      No filters configured.
                    </p>
                  </div>
                </div>

                <div class="grid grid-cols-3 gap-2">
                  <button
                    id="run-query-button"
                    type="submit"
                    disabled={@query_running}
                    class="rounded-lg bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {if @query_running, do: "Running...", else: "Run query"}
                  </button>

                  <button
                    id="cancel-query-button"
                    type="button"
                    phx-click="cancel_query"
                    disabled={not @query_running}
                    class="rounded-lg border border-gray-300 px-3 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Cancel
                  </button>

                  <button
                    id="reset-query-button"
                    type="button"
                    phx-click="reset_query"
                    class="rounded-lg border border-gray-300 px-3 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50"
                  >
                    Reset
                  </button>
                </div>
              </form>
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

              <div class="mt-4 border-t border-gray-100 pt-3">
                <p class="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-600">
                  Full Config Export
                </p>
                <textarea
                  id="full-config-json"
                  readonly
                  class="h-28 w-full rounded-lg border-gray-300 font-mono text-xs text-gray-700"
                  value={
                    build_full_config_json(
                      @selected_table,
                      @selected_joins,
                      @selected_columns,
                      @filters,
                      @sort_column_ref,
                      @sort_direction,
                      @query_page_size
                    )
                  }
                ></textarea>
              </div>

              <div class="mt-3">
                <form
                  id="import-config-form"
                  phx-change="set_import_config"
                  phx-submit="import_config"
                  class="space-y-2"
                >
                  <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">
                    Import Config JSON
                  </p>

                  <textarea
                    id="import-config-json"
                    name="import[json]"
                    value={@import_config_json}
                    class="h-24 w-full rounded-lg border-gray-300 font-mono text-xs text-gray-700 focus:border-blue-400 focus:ring-blue-200"
                    placeholder="Paste exported config JSON"
                  ></textarea>

                  <button
                    type="submit"
                    class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50"
                  >
                    Import config
                  </button>
                </form>
              </div>
            </div>
          </section>
        </div>

        <div class="border-t border-gray-100 p-4">
          <section class="rounded-xl border border-gray-200 bg-white p-4">
            <div class="mb-3 flex items-center justify-between">
              <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
                Joined Results
              </h2>
              <div class="flex items-center gap-2">
                <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-700">
                  page size {@query_page_size}
                </span>
                <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-700">
                  {@query_total_rows} rows
                </span>
                <span
                  :if={@query_running}
                  class="rounded-full bg-amber-50 px-2 py-0.5 text-xs font-semibold text-amber-700"
                >
                  running
                </span>
              </div>
            </div>

            <p :if={@query_error} class="mb-2 text-sm text-rose-600">{@query_error}</p>

            <div :if={@query_sql} class="mb-3">
              <p class="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-600">
                SQL Preview
              </p>
              <textarea
                id="joined-query-sql"
                readonly
                class="h-24 w-full rounded-lg border-gray-300 font-mono text-xs text-gray-700"
                value={@query_sql}
              ></textarea>
            </div>

            <div class="mb-3 flex items-center justify-between rounded-lg border border-gray-200 px-3 py-2">
              <button
                id="query-prev-page"
                type="button"
                phx-click="prev_page"
                disabled={@query_running or @query_page <= 1 or @query_total_pages <= 1}
                class="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Prev
              </button>

              <p id="query-page-indicator" class="text-xs font-semibold text-gray-700">
                Page {@query_page} / {display_total_pages(@query_total_pages)}
              </p>

              <button
                id="query-next-page"
                type="button"
                phx-click="next_page"
                disabled={
                  @query_running or @query_page >= @query_total_pages or @query_total_pages <= 1
                }
                class="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Next
              </button>
            </div>

            <div class="mb-3 grid grid-cols-2 gap-2">
              <button
                id="download-csv-page"
                type="button"
                phx-click="download_csv"
                phx-value-scope="page"
                disabled={@query_rows == [] or @query_running}
                class="rounded-lg border border-gray-300 px-3 py-2 text-xs font-semibold text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Download current page CSV
              </button>

              <button
                id="download-csv-all"
                type="button"
                phx-click="download_csv"
                phx-value-scope="all"
                disabled={@query_running}
                class="rounded-lg border border-gray-300 px-3 py-2 text-xs font-semibold text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Download all rows CSV
              </button>
            </div>

            <p :if={@query_rows == [] and @query_error == nil} class="text-sm text-gray-600">
              Run a query to preview joined results.
            </p>

            <div
              :if={@query_rows != [] and @query_error == nil}
              class="max-h-[42vh] overflow-auto rounded-lg border border-gray-200"
            >
              <table
                id="joined-results-table"
                class="min-w-full divide-y divide-gray-200 text-left text-xs"
              >
                <thead class="sticky top-0 z-10 bg-gray-50">
                  <tr>
                    <th
                      :for={column <- @query_columns}
                      class="whitespace-nowrap px-3 py-2 font-semibold text-gray-700"
                    >
                      {column}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <tr :for={row <- @query_rows}>
                    <td
                      :for={column <- @query_columns}
                      class="max-w-[260px] px-3 py-2 align-top font-mono text-[11px] text-gray-700"
                    >
                      {format_cell(Map.get(row, column))}
                    </td>
                  </tr>
                </tbody>
              </table>
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
        |> assign(:column_cache, %{})
        |> assign(:available_joins, [])
        |> assign(:selected_joins, [])
        |> assign(:available_columns, [])
        |> assign(:selected_columns, [])
        |> assign(:filters, [])
        |> assign(:filter_seq, 0)
        |> assign(:join_config_json, empty_join_config())
        |> assign(:selecto_join_config, empty_selecto_join_config())
        |> assign(:query_columns, [])
        |> assign(:query_rows, [])
        |> assign(:query_sql, nil)
        |> assign(:query_error, nil)
        |> assign(:query_builder_error, nil)
        |> assign(:query_page, 1)
        |> assign(:query_total_rows, 0)
        |> assign(:query_total_pages, 0)
        |> assign(:sort_column_ref, nil)
        |> assign(:sort_direction, "asc")
        |> assign(:query_running, false)
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
    |> assign(:column_cache, %{})
    |> assign(:available_joins, [])
    |> assign(:selected_joins, [])
    |> assign(:available_columns, [])
    |> assign(:selected_columns, [])
    |> assign(:filters, [])
    |> assign(:filter_seq, 0)
    |> assign(:query_columns, [])
    |> assign(:query_rows, [])
    |> assign(:query_sql, nil)
    |> assign(:query_error, nil)
    |> assign(:query_builder_error, nil)
    |> assign(:query_page, 1)
    |> assign(:query_total_rows, 0)
    |> assign(:query_total_pages, 0)
    |> assign(:sort_column_ref, nil)
    |> assign(:sort_direction, "asc")
    |> assign(:query_running, false)
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
    |> assign(:column_cache, %{})
    |> assign(:available_joins, available_joins)
    |> assign(:selected_joins, [])
    |> assign(:selected_columns, [])
    |> assign(:filters, [])
    |> assign(:filter_seq, 0)
    |> assign(:query_columns, [])
    |> assign(:query_rows, [])
    |> assign(:query_sql, nil)
    |> assign(:query_error, nil)
    |> assign(:query_builder_error, nil)
    |> assign(:query_page, 1)
    |> assign(:query_total_rows, 0)
    |> assign(:query_total_pages, 0)
    |> assign(:sort_column_ref, nil)
    |> assign(:sort_direction, "asc")
    |> assign(:query_running, false)
    |> assign(:preview_error, preview_error)
    |> assign(:join_error, join_error_message(join_errors))
    |> refresh_output_configs()
    |> refresh_query_state()
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
            |> refresh_query_state()
            |> assign(:query_columns, [])
            |> assign(:query_rows, [])
            |> assign(:query_sql, nil)
            |> assign(:query_error, nil)
            |> assign(:query_page, 1)
            |> assign(:query_total_rows, 0)
            |> assign(:query_total_pages, 0)
            |> assign(:query_running, false)

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
          |> refresh_query_state()
          |> assign(:query_columns, [])
          |> assign(:query_rows, [])
          |> assign(:query_sql, nil)
          |> assign(:query_error, nil)
          |> assign(:query_page, 1)
          |> assign(:query_total_rows, 0)
          |> assign(:query_total_pages, 0)
          |> assign(:query_running, false)

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

  defp refresh_query_state(socket) do
    {column_cache, column_errors} =
      ensure_column_cache(socket.assigns.column_cache, socket.assigns.connected_tables)

    available_columns = build_available_columns(socket.assigns.connected_tables, column_cache)

    selected_columns =
      socket.assigns.selected_columns
      |> normalize_selected_columns()
      |> Enum.filter(&column_available?(available_columns, &1))
      |> maybe_default_columns(socket.assigns.selected_table, available_columns)

    filters = normalize_filters(socket.assigns.filters, available_columns)

    sort_column_ref =
      normalize_sort_column_ref(
        socket.assigns.sort_column_ref,
        selected_columns,
        available_columns
      )

    sort_direction = normalize_sort_direction(socket.assigns.sort_direction)

    socket
    |> assign(:column_cache, column_cache)
    |> assign(:available_columns, available_columns)
    |> assign(:selected_columns, selected_columns)
    |> assign(:filters, filters)
    |> assign(:sort_column_ref, sort_column_ref)
    |> assign(:sort_direction, sort_direction)
    |> assign(:query_builder_error, query_builder_error_message(column_errors))
  end

  defp ensure_column_cache(column_cache, connected_tables) do
    Enum.reduce(connected_tables, {column_cache, []}, fn table_key, {cache, errors} ->
      if Map.has_key?(cache, table_key) do
        {cache, errors}
      else
        {schema, table} = table_key

        case SchemaExplorer.table_columns(schema, table) do
          {:ok, columns} ->
            {Map.put(cache, table_key, columns), errors}

          {:error, reason} ->
            {Map.put(cache, table_key, []), [db_error(reason) | errors]}
        end
      end
    end)
  end

  defp build_available_columns(connected_tables, column_cache) do
    connected_tables
    |> Enum.sort_by(&table_key_to_string/1)
    |> Enum.flat_map(fn {schema, table} = key ->
      column_cache
      |> Map.get(key, [])
      |> Enum.map(fn %{name: name, data_type: data_type} ->
        %{
          id: column_ref(schema, table, name),
          schema: schema,
          table: table,
          column: name,
          data_type: data_type,
          table_label: "#{schema}.#{table}",
          label: "#{schema}.#{table}.#{name}"
        }
      end)
    end)
  end

  defp maybe_default_columns([], selected_table, available_columns) do
    base_columns =
      available_columns
      |> Enum.filter(fn column ->
        not is_nil(selected_table) and
          column.schema == selected_table.schema and column.table == selected_table.table
      end)
      |> Enum.take(@default_column_count)
      |> Enum.map(& &1.id)

    if base_columns == [] do
      available_columns
      |> Enum.take(@default_column_count)
      |> Enum.map(& &1.id)
    else
      base_columns
    end
  end

  defp maybe_default_columns(selected_columns, _selected_table, _available_columns),
    do: selected_columns

  defp column_available?(available_columns, column_ref) do
    Enum.any?(available_columns, &(&1.id == column_ref))
  end

  defp normalize_filters(filters, available_columns) do
    valid_column_ids = MapSet.new(Enum.map(available_columns, & &1.id))

    default_column_ref =
      case List.first(available_columns) do
        nil -> nil
        column -> column.id
      end

    Enum.map(filters, fn filter ->
      column_ref =
        if MapSet.member?(valid_column_ids, filter.column_ref) do
          filter.column_ref
        else
          default_column_ref
        end

      column = find_column(available_columns, column_ref)
      operator = normalize_operator_for_column(filter.operator, column)

      %{
        filter
        | column_ref: column_ref,
          operator: operator,
          value: normalize_filter_value(filter.value, column, operator)
      }
    end)
  end

  defp normalize_operator(operator)
       when operator in [
              "eq",
              "neq",
              "gt",
              "gte",
              "lt",
              "lte",
              "contains",
              "starts_with",
              "ends_with",
              "is_null",
              "is_not_null"
            ],
       do: operator

  defp normalize_operator(_), do: "eq"

  defp sanitize_query_state(socket) do
    valid_column_ids = MapSet.new(Enum.map(socket.assigns.available_columns, & &1.id))

    selected_columns =
      socket.assigns.selected_columns
      |> normalize_selected_columns()
      |> Enum.filter(&MapSet.member?(valid_column_ids, &1))

    filters = normalize_filters(socket.assigns.filters, socket.assigns.available_columns)

    sort_column_ref =
      normalize_sort_column_ref(
        socket.assigns.sort_column_ref,
        selected_columns,
        socket.assigns.available_columns
      )

    sort_direction = normalize_sort_direction(socket.assigns.sort_direction)
    query_page_size = normalize_query_page_size(socket.assigns.query_page_size)

    socket
    |> assign(:selected_columns, selected_columns)
    |> assign(:filters, filters)
    |> assign(:sort_column_ref, sort_column_ref)
    |> assign(:sort_direction, sort_direction)
    |> assign(:query_page_size, query_page_size)
  end

  defp start_query_run(socket) do
    query_socket = query_socket_for_execution(socket.assigns)

    socket
    |> cancel_async(:studio_query)
    |> assign(:query_running, true)
    |> assign(:query_error, nil)
    |> start_async(:studio_query, fn -> execute_joined_query(query_socket) end)
  end

  defp reset_query_state(socket) do
    socket
    |> cancel_async(:studio_query)
    |> assign(:query_columns, [])
    |> assign(:query_rows, [])
    |> assign(:query_sql, nil)
    |> assign(:query_error, nil)
    |> assign(:query_page, 1)
    |> assign(:query_total_rows, 0)
    |> assign(:query_total_pages, 0)
    |> assign(:query_running, false)
  end

  defp execute_joined_query(query_socket) do
    with {:ok, query} <- build_joined_query(query_socket),
         {:ok, %{rows: [[total_rows_raw]]}} <-
           SQL.query(Repo, query.count_sql, query.count_params, timeout: @query_timeout_ms) do
      total_rows = normalize_total_rows(total_rows_raw)
      total_pages = compute_total_pages(total_rows, query_socket.assigns.query_page_size)
      clamped_page = clamp_query_page(query_socket.assigns.query_page, total_pages)

      query =
        if clamped_page == query.page do
          query
        else
          {:ok, rebuilt_query} = build_joined_query(query_socket, clamped_page)
          rebuilt_query
        end

      case SQL.query(Repo, query.sql, query.params, timeout: @query_timeout_ms) do
        {:ok, %{columns: columns, rows: rows}} ->
          shaped_rows =
            Enum.map(rows, fn values ->
              columns
              |> Enum.zip(values)
              |> Enum.into(%{})
            end)

          {:ok,
           %{
             columns: columns,
             rows: shaped_rows,
             sql: query.sql,
             page: clamped_page,
             total_rows: total_rows,
             total_pages: total_pages
           }}

        {:error, reason} ->
          {:error, "Could not run joined query: #{db_error(reason)}"}
      end
    else
      {:error, message} ->
        {:error, db_error(message)}

      {:ok, _other} ->
        {:error, "Could not determine total row count"}
    end
  end

  defp query_socket_for_execution(assigns) do
    %{
      assigns: %{
        selected_table: assigns.selected_table,
        selected_joins: assigns.selected_joins,
        available_columns: assigns.available_columns,
        selected_columns: assigns.selected_columns,
        filters: assigns.filters,
        sort_column_ref: assigns.sort_column_ref,
        sort_direction: assigns.sort_direction,
        query_page_size: assigns.query_page_size,
        query_page: assigns.query_page
      }
    }
  end

  defp download_csv(socket, "page") do
    if socket.assigns.query_rows == [] or socket.assigns.query_columns == [] do
      {:error, "Run a query first before downloading CSV", socket}
    else
      csv = encode_csv(socket.assigns.query_columns, socket.assigns.query_rows)

      {:ok,
       push_event(socket, "download_csv", %{
         filename: "studio_query_page_#{socket.assigns.query_page}.csv",
         content: csv
       })}
    end
  end

  defp download_csv(socket, "all") do
    query_socket =
      socket.assigns
      |> query_socket_for_execution()
      |> put_in([:assigns, :query_page_size], @max_csv_export_rows)
      |> put_in([:assigns, :query_page], 1)

    with {:ok, query} <- build_joined_query(query_socket),
         {:ok, %{rows: [[total_rows_raw]]}} <-
           SQL.query(Repo, query.count_sql, query.count_params, timeout: @query_timeout_ms),
         {:ok, %{columns: columns, rows: rows}} <-
           SQL.query(Repo, query.sql, query.params, timeout: @query_timeout_ms) do
      total_rows = normalize_total_rows(total_rows_raw)

      shaped_rows =
        Enum.map(rows, fn values ->
          columns
          |> Enum.zip(values)
          |> Enum.into(%{})
        end)

      csv = encode_csv(columns, shaped_rows)

      socket =
        if total_rows > @max_csv_export_rows do
          put_flash(
            socket,
            :info,
            "CSV export limited to #{@max_csv_export_rows} rows (#{total_rows} total matched)"
          )
        else
          socket
        end

      {:ok,
       push_event(socket, "download_csv", %{
         filename: "studio_query_all.csv",
         content: csv
       })}
    else
      {:error, reason} -> {:error, "Could not export CSV: #{db_error(reason)}", socket}
      {:ok, _other} -> {:error, "Could not export CSV", socket}
    end
  end

  defp download_csv(socket, _scope), do: {:error, "Unsupported CSV export scope", socket}

  defp encode_csv(columns, rows) do
    header = Enum.map_join(columns, ",", &csv_escape/1)

    body =
      Enum.map_join(rows, "\n", fn row ->
        columns
        |> Enum.map(fn column -> Map.get(row, column) end)
        |> Enum.map_join(",", &csv_escape/1)
      end)

    if body == "" do
      header <> "\n"
    else
      header <> "\n" <> body <> "\n"
    end
  end

  defp csv_escape(nil), do: ""

  defp csv_escape(value) do
    text =
      case value do
        %Date{} -> Date.to_iso8601(value)
        %Time{} -> Time.to_iso8601(value)
        %NaiveDateTime{} -> NaiveDateTime.to_iso8601(value)
        %DateTime{} -> DateTime.to_iso8601(value)
        value when is_binary(value) -> value
        value -> to_string(value)
      end

    escaped = String.replace(text, "\"", "\"\"")

    if String.contains?(escaped, [",", "\n", "\r", "\""]) do
      "\"#{escaped}\""
    else
      escaped
    end
  end

  defp build_full_config_json(
         selected_table,
         selected_joins,
         selected_columns,
         filters,
         sort_column_ref,
         sort_direction,
         query_page_size
       ) do
    %{
      version: 1,
      base_table: full_table_name(selected_table),
      selected_join_ids: Enum.map(selected_joins, & &1.id),
      selected_columns: selected_columns,
      filters: filters,
      sort: %{column_ref: sort_column_ref, direction: sort_direction},
      page_size: query_page_size
    }
    |> Jason.encode!(pretty: true)
  end

  defp parse_import_config(json) do
    payload = to_string(json || "") |> String.trim()

    if payload == "" do
      {:error, "Paste a config JSON payload to import"}
    else
      case Jason.decode(payload) do
        {:ok, decoded} when is_map(decoded) ->
          {:ok,
           %{
             base_table: normalize_optional_string(Map.get(decoded, "base_table")),
             selected_join_ids: normalize_string_list(Map.get(decoded, "selected_join_ids", [])),
             selected_columns: normalize_string_list(Map.get(decoded, "selected_columns", [])),
             filters: Map.get(decoded, "filters", []),
             sort_column_ref: normalize_optional_string(get_in(decoded, ["sort", "column_ref"])),
             sort_direction: get_in(decoded, ["sort", "direction"]),
             page_size: Map.get(decoded, "page_size")
           }}

        {:ok, _decoded} ->
          {:error, "Import payload must be a JSON object"}

        {:error, _reason} ->
          {:error, "Invalid JSON payload"}
      end
    end
  end

  defp apply_imported_config(socket, imported) do
    case find_table_by_full_name(socket.assigns.tables, imported.base_table) do
      nil ->
        {:error, "Imported base table is not available", socket}

      table ->
        filters = normalize_saved_filters(imported.filters)

        socket =
          socket
          |> load_selected_table(table)
          |> rebuild_selected_joins(imported.selected_join_ids)
          |> assign(:selected_columns, normalize_selected_columns(imported.selected_columns))
          |> assign(:filters, filters)
          |> assign(:filter_seq, next_filter_seq(filters))
          |> assign(:sort_column_ref, imported.sort_column_ref)
          |> assign(:sort_direction, normalize_sort_direction(imported.sort_direction))
          |> assign(:query_page_size, normalize_query_page_size(imported.page_size))
          |> assign(:query_page, 1)
          |> sanitize_query_state()
          |> reset_query_state()

        {:ok, socket}
    end
  end

  defp build_joined_query(socket, page_override \\ nil) do
    selected_table = socket.assigns.selected_table
    page_size = socket.assigns.query_page_size
    page = page_override || socket.assigns.query_page

    cond do
      is_nil(selected_table) ->
        {:error, "Pick a base table first"}

      socket.assigns.selected_columns == [] ->
        {:error, "Pick at least one column before running a query"}

      true ->
        available_columns_by_id = Map.new(socket.assigns.available_columns, &{&1.id, &1})

        with {:ok, table_aliases, join_clauses} <-
               build_aliases_and_joins(selected_table, socket.assigns.selected_joins),
             {:ok, select_clauses} <-
               build_select_clauses(
                 socket.assigns.selected_columns,
                 available_columns_by_id,
                 table_aliases
               ),
             {:ok, where_clauses, params} <-
               build_where_clauses(socket.assigns.filters, available_columns_by_id, table_aliases),
             {:ok, order_clause} <-
               build_order_clause(
                 socket.assigns.sort_column_ref,
                 socket.assigns.sort_direction,
                 available_columns_by_id,
                 table_aliases
               ) do
          joins_sql = if join_clauses == [], do: "", else: "\n" <> Enum.join(join_clauses, "\n")

          where_sql =
            if where_clauses == [] do
              ""
            else
              "\nwhere " <> Enum.join(where_clauses, " and ")
            end

          order_sql = if is_nil(order_clause), do: "", else: "\norder by " <> order_clause

          page = max(page, 1)
          offset = (page - 1) * page_size
          limit_placeholder = "$#{length(params) + 1}"
          offset_placeholder = "$#{length(params) + 2}"
          query_params = params ++ [page_size, offset]

          sql =
            """
            select #{Enum.join(select_clauses, ", ")}
            from #{quote_table(selected_table.schema, selected_table.table)} as t0#{joins_sql}#{where_sql}#{order_sql}
            limit #{limit_placeholder} offset #{offset_placeholder}
            """
            |> String.trim()

          count_sql =
            """
            select count(*)
            from #{quote_table(selected_table.schema, selected_table.table)} as t0#{joins_sql}#{where_sql}
            """
            |> String.trim()

          {:ok,
           %{
             sql: sql,
             params: query_params,
             count_sql: count_sql,
             count_params: params,
             page: page
           }}
        end
    end
  end

  defp build_aliases_and_joins(selected_table, selected_joins) do
    base_key = table_key(selected_table.schema, selected_table.table)

    Enum.reduce_while(selected_joins, {%{base_key => "t0"}, [], 1}, fn join,
                                                                       {aliases, join_clauses,
                                                                        next_alias_idx} ->
      parent_key = table_key(join.parent_schema, join.parent_table)
      child_key = table_key(join.child_schema, join.child_table)

      case Map.get(aliases, parent_key) do
        nil ->
          {:halt, {:error, "Invalid join path: #{parent_full_name(join)} is disconnected"}}

        parent_alias ->
          {aliases, child_alias, next_alias_idx} =
            case Map.get(aliases, child_key) do
              nil ->
                alias_name = "t#{next_alias_idx}"
                {Map.put(aliases, child_key, alias_name), alias_name, next_alias_idx + 1}

              existing_alias ->
                {aliases, existing_alias, next_alias_idx}
            end

          on_clause =
            join.on
            |> Enum.map(fn %{parent_column: parent_column, child_column: child_column} ->
              "#{parent_alias}.#{quote_identifier(parent_column)} = #{child_alias}.#{quote_identifier(child_column)}"
            end)
            |> Enum.join(" and ")

          join_clause =
            "left join #{quote_table(join.child_schema, join.child_table)} as #{child_alias} on #{on_clause}"

          {:cont, {aliases, join_clauses ++ [join_clause], next_alias_idx}}
      end
    end)
    |> case do
      {:error, _message} = error -> error
      {aliases, join_clauses, _next_alias_idx} -> {:ok, aliases, join_clauses}
    end
  end

  defp build_select_clauses(selected_columns, available_columns_by_id, table_aliases) do
    select_clauses =
      selected_columns
      |> Enum.reduce([], fn column_ref, clauses ->
        case Map.get(available_columns_by_id, column_ref) do
          nil ->
            clauses

          column ->
            table_alias = Map.get(table_aliases, table_key(column.schema, column.table))

            if is_nil(table_alias) do
              clauses
            else
              column_alias = column_sql_alias(column)

              clauses ++
                [
                  "#{table_alias}.#{quote_identifier(column.column)} as #{quote_identifier(column_alias)}"
                ]
            end
        end
      end)

    if select_clauses == [] do
      {:error, "No valid selected columns available in the current join graph"}
    else
      {:ok, select_clauses}
    end
  end

  defp build_where_clauses(filters, available_columns_by_id, table_aliases) do
    Enum.reduce_while(filters, {:ok, [], []}, fn filter, {:ok, clauses, params} ->
      case Map.get(available_columns_by_id, filter.column_ref) do
        nil ->
          {:cont, {:ok, clauses, params}}

        column ->
          table_alias = Map.get(table_aliases, table_key(column.schema, column.table))

          if is_nil(table_alias) do
            {:cont, {:ok, clauses, params}}
          else
            column_sql = "#{table_alias}.#{quote_identifier(column.column)}"

            case build_filter_clause(column_sql, filter.operator, filter.value, params, column) do
              {:ok, nil, next_params} ->
                {:cont, {:ok, clauses, next_params}}

              {:ok, clause, next_params} ->
                {:cont, {:ok, clauses ++ [clause], next_params}}

              {:error, message} ->
                {:halt, {:error, message}}
            end
          end
      end
    end)
  end

  defp build_order_clause(sort_column_ref, sort_direction, available_columns_by_id, table_aliases) do
    case Map.get(available_columns_by_id, sort_column_ref) do
      nil ->
        {:ok, nil}

      column ->
        table_alias = Map.get(table_aliases, table_key(column.schema, column.table))

        if is_nil(table_alias) do
          {:ok, nil}
        else
          direction = normalize_sort_direction(sort_direction) |> String.upcase()
          {:ok, "#{table_alias}.#{quote_identifier(column.column)} #{direction}"}
        end
    end
  end

  defp build_filter_clause(column_sql, operator, value, params, column) do
    operator = normalize_operator_for_column(operator, column)
    normalized_value = value |> to_string() |> String.trim()

    case operator do
      "eq" ->
        build_typed_value_filter(column_sql, "=", normalized_value, params, column)

      "neq" ->
        build_typed_value_filter(column_sql, "!=", normalized_value, params, column)

      "gt" ->
        build_typed_value_filter(column_sql, ">", normalized_value, params, column)

      "gte" ->
        build_typed_value_filter(column_sql, ">=", normalized_value, params, column)

      "lt" ->
        build_typed_value_filter(column_sql, "<", normalized_value, params, column)

      "lte" ->
        build_typed_value_filter(column_sql, "<=", normalized_value, params, column)

      "contains" ->
        build_typed_value_filter(
          "cast(#{column_sql} as text)",
          "ilike",
          "%#{normalized_value}%",
          params,
          %{column | data_type: "text"}
        )

      "starts_with" ->
        build_typed_value_filter(
          "cast(#{column_sql} as text)",
          "ilike",
          "#{normalized_value}%",
          params,
          %{column | data_type: "text"}
        )

      "ends_with" ->
        build_typed_value_filter(
          "cast(#{column_sql} as text)",
          "ilike",
          "%#{normalized_value}",
          params,
          %{column | data_type: "text"}
        )

      "is_null" ->
        {:ok, "#{column_sql} is null", params}

      "is_not_null" ->
        {:ok, "#{column_sql} is not null", params}

      _ ->
        {:error, "Unsupported filter operator"}
    end
  end

  defp build_typed_value_filter(column_sql, operator_sql, value, params, column) do
    with {:ok, typed_value} <- coerce_filter_value(column, value) do
      case typed_value do
        :skip -> {:ok, nil, params}
        actual_value -> build_value_filter(column_sql, operator_sql, actual_value, params)
      end
    end
  end

  defp build_value_filter(_column_sql, _operator_sql, "", params), do: {:ok, nil, params}
  defp build_value_filter(_column_sql, _operator_sql, nil, params), do: {:ok, nil, params}

  defp build_value_filter(column_sql, operator_sql, value, params) do
    placeholder = "$#{length(params) + 1}"
    {:ok, "#{column_sql} #{operator_sql} #{placeholder}", params ++ [value]}
  end

  defp column_sql_alias(column) do
    "#{column.schema}__#{column.table}__#{column.column}"
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end

  defp quote_table(schema, table) do
    "#{quote_identifier(schema)}.#{quote_identifier(table)}"
  end

  defp quote_identifier(identifier) do
    escaped = String.replace(identifier, "\"", "\"\"")
    ~s("#{escaped}")
  end

  defp column_ref(schema, table, column), do: "#{schema}|#{table}|#{column}"

  defp build_selecto_handoff_snippet(
         selected_table,
         selected_columns,
         filters,
         sort_column_ref,
         sort_direction
       ) do
    select_fields =
      selected_columns
      |> Enum.map(&column_ref_to_field/1)
      |> Enum.reject(&is_nil/1)

    filter_terms =
      filters
      |> Enum.map(&filter_to_selecto_term/1)
      |> Enum.reject(&is_nil/1)

    order_terms =
      case column_ref_to_field(sort_column_ref) do
        nil -> []
        field -> [{field, sort_direction_atom(sort_direction)}]
      end

    lines =
      [
        "# Generated from /studio",
        "selecto = Selecto.configure(your_domain, SelectoTest.Repo)",
        "",
        "query =",
        "  selecto",
        "  |> Selecto.select(#{inspect(select_fields, pretty: true, limit: :infinity)})"
      ] ++
        handoff_filter_lines(filter_terms) ++
        handoff_order_lines(order_terms) ++
        ["", "results = Selecto.execute(query)"]

    if is_nil(selected_table) do
      "# Pick a base table first"
    else
      Enum.join(lines, "\n")
    end
  end

  defp handoff_filter_lines([]), do: []

  defp handoff_filter_lines(filter_terms) do
    ["  |> Selecto.filter(#{inspect(filter_terms, pretty: true, limit: :infinity)})"]
  end

  defp handoff_order_lines([]), do: []

  defp handoff_order_lines(order_terms) do
    ["  |> Selecto.order_by(#{inspect(order_terms, pretty: true, limit: :infinity)})"]
  end

  defp filter_to_selecto_term(%{column_ref: column_ref, operator: operator, value: value}) do
    with field when not is_nil(field) <- column_ref_to_field(column_ref) do
      case normalize_operator(operator) do
        "eq" -> {field, value}
        "neq" -> {field, {:not, value}}
        "gt" -> {field, {:>, value}}
        "gte" -> {field, {:>=, value}}
        "lt" -> {field, {:<, value}}
        "lte" -> {field, {:<=, value}}
        "contains" -> {field, {:ilike, "%#{value}%"}}
        "starts_with" -> {field, {:ilike, "#{value}%"}}
        "ends_with" -> {field, {:ilike, "%#{value}"}}
        "is_null" -> {field, nil}
        "is_not_null" -> {field, {:not, nil}}
        _ -> nil
      end
    end
  end

  defp filter_to_selecto_term(_), do: nil

  defp column_ref_to_field(nil), do: nil

  defp column_ref_to_field(column_ref) do
    case String.split(to_string(column_ref), "|", parts: 3) do
      [_schema, table, column] -> "#{table}.#{column}"
      _ -> nil
    end
  end

  defp query_page_size_options, do: [10, 25, 50, 100, 200]

  defp normalize_query_page_size(value) when is_integer(value) do
    value
    |> max(1)
    |> min(@max_query_page_size)
  end

  defp normalize_query_page_size(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> normalize_query_page_size(parsed)
      _ -> @query_page_size
    end
  end

  defp normalize_query_page_size(_), do: @query_page_size

  defp normalize_optional_string(nil), do: nil

  defp normalize_optional_string(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_string_list(values) when is_list(values) do
    values
    |> Enum.map(&normalize_optional_string/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_string_list(value), do: normalize_string_list([value])

  defp sort_direction_atom(direction) do
    case normalize_sort_direction(direction) do
      "desc" -> :desc
      _ -> :asc
    end
  end

  defp grouped_available_columns(available_columns) do
    available_columns
    |> Enum.group_by(& &1.table_label)
    |> Enum.sort_by(fn {table_label, _columns} -> table_label end)
    |> Enum.map(fn {table_label, columns} ->
      %{table_label: table_label, columns: columns}
    end)
  end

  defp column_selected?(selected_columns, column_ref) do
    Enum.member?(selected_columns, column_ref)
  end

  defp normalize_selected_columns(nil), do: []

  defp normalize_selected_columns(selected_columns) when is_list(selected_columns) do
    selected_columns
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_selected_columns(selected_column) do
    normalize_selected_columns([selected_column])
  end

  defp normalize_saved_filters(nil), do: []

  defp normalize_saved_filters(filters) when is_list(filters) do
    filters
    |> Enum.map(&normalize_saved_filter/1)
    |> Enum.reject(&is_nil/1)
    |> ensure_unique_filter_ids()
  end

  defp normalize_saved_filters(_), do: []

  defp normalize_saved_filter(filter) when is_map(filter) do
    column_ref = Map.get(filter, :column_ref) || Map.get(filter, "column_ref")

    if is_nil(column_ref) do
      nil
    else
      %{
        id: to_string(Map.get(filter, :id) || Map.get(filter, "id") || ""),
        column_ref: to_string(column_ref),
        operator: to_string(Map.get(filter, :operator) || Map.get(filter, "operator") || "eq"),
        value: to_string(Map.get(filter, :value) || Map.get(filter, "value") || "")
      }
    end
  end

  defp normalize_saved_filter(_), do: nil

  defp ensure_unique_filter_ids(filters) do
    {_, normalized} =
      Enum.reduce(filters, {MapSet.new(), []}, fn filter, {used_ids, acc} ->
        candidate_id =
          filter.id
          |> to_string()
          |> String.trim()

        unique_id =
          if candidate_id == "" do
            next_generated_filter_id(used_ids)
          else
            ensure_unique_filter_id(candidate_id, used_ids)
          end

        {MapSet.put(used_ids, unique_id), acc ++ [%{filter | id: unique_id}]}
      end)

    normalized
  end

  defp ensure_unique_filter_id(candidate_id, used_ids) do
    if MapSet.member?(used_ids, candidate_id) do
      next_generated_filter_id(used_ids)
    else
      candidate_id
    end
  end

  defp next_generated_filter_id(used_ids) do
    next_generated_filter_id(used_ids, 1)
  end

  defp next_generated_filter_id(used_ids, index) do
    candidate = "f#{index}"

    if MapSet.member?(used_ids, candidate) do
      next_generated_filter_id(used_ids, index + 1)
    else
      candidate
    end
  end

  defp next_filter_seq(filters) do
    max_numeric_id =
      filters
      |> Enum.map(fn filter ->
        case Regex.run(~r/^f(\d+)$/, filter.id) do
          [_, value] -> String.to_integer(value)
          _ -> 0
        end
      end)
      |> Enum.max(fn -> 0 end)

    max(max_numeric_id, length(filters))
  end

  defp filter_operator_options(filter, available_columns) do
    column = find_column(available_columns, filter.column_ref)

    column
    |> filter_operator_values_for_column()
    |> Enum.map(fn value ->
      %{label: operator_label(value), value: value}
    end)
  end

  defp filter_operator_values_for_column(nil), do: ["eq", "neq", "is_null", "is_not_null"]

  defp filter_operator_values_for_column(column) do
    case column_type_kind(column.data_type) do
      :text -> ["eq", "neq", "contains", "starts_with", "ends_with", "is_null", "is_not_null"]
      :boolean -> ["eq", "neq", "is_null", "is_not_null"]
      :number -> ["eq", "neq", "gt", "gte", "lt", "lte", "is_null", "is_not_null"]
      :date -> ["eq", "neq", "gt", "gte", "lt", "lte", "is_null", "is_not_null"]
      :datetime -> ["eq", "neq", "gt", "gte", "lt", "lte", "is_null", "is_not_null"]
      :time -> ["eq", "neq", "gt", "gte", "lt", "lte", "is_null", "is_not_null"]
      :other -> ["eq", "neq", "is_null", "is_not_null"]
    end
  end

  defp operator_label("eq"), do: "="
  defp operator_label("neq"), do: "!="
  defp operator_label("gt"), do: ">"
  defp operator_label("gte"), do: ">="
  defp operator_label("lt"), do: "<"
  defp operator_label("lte"), do: "<="
  defp operator_label("contains"), do: "contains"
  defp operator_label("starts_with"), do: "starts with"
  defp operator_label("ends_with"), do: "ends with"
  defp operator_label("is_null"), do: "is null"
  defp operator_label("is_not_null"), do: "is not null"
  defp operator_label(_), do: "="

  defp filter_input_kind(filter, available_columns) do
    case find_column(available_columns, filter.column_ref) do
      nil ->
        :text

      column ->
        case column_type_kind(column.data_type) do
          :boolean -> :boolean
          :number -> :number
          :date -> :date
          :datetime -> :datetime
          :time -> :time
          _ -> :text
        end
    end
  end

  defp normalize_datetime_value_for_input(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(" ", "T")
    |> String.replace(~r/:\d{2}(?:\.\d+)?$/, "")
  end

  defp normalize_datetime_value_for_input(_), do: ""

  defp normalize_time_value_for_input(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(~r/:\d{2}(?:\.\d+)?$/, "")
  end

  defp normalize_time_value_for_input(_), do: ""

  defp normalize_operator_for_column(operator, column) do
    normalized = normalize_operator(operator)
    allowed = filter_operator_values_for_column(column)

    if normalized in allowed do
      normalized
    else
      List.first(allowed) || "eq"
    end
  end

  defp normalize_filter_value(value, column, operator) do
    normalized_value = to_string(value || "")

    cond do
      not operator_requires_value?(operator) ->
        ""

      is_nil(column) ->
        normalized_value

      column_type_kind(column.data_type) == :boolean ->
        if normalized_value in ["true", "false", "1", "0"], do: normalized_value, else: "true"

      true ->
        normalized_value
    end
  end

  defp coerce_filter_value(_column, ""), do: {:ok, :skip}

  defp coerce_filter_value(column, value) do
    case column_type_kind(column.data_type) do
      :boolean ->
        parse_boolean_value(value, column)

      :number ->
        parse_number_value(value, column)

      :date ->
        parse_date_value(value, column)

      :datetime ->
        parse_datetime_value(value, column)

      :time ->
        parse_time_value(value, column)

      _ ->
        {:ok, value}
    end
  end

  defp parse_boolean_value(value, column) do
    case String.downcase(String.trim(to_string(value))) do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      "1" -> {:ok, true}
      "0" -> {:ok, false}
      _ -> {:error, "Invalid boolean value for #{column.label}"}
    end
  end

  defp parse_number_value(value, column) do
    normalized = String.trim(to_string(value))

    if integer_data_type?(column.data_type) do
      case Integer.parse(normalized) do
        {parsed, ""} -> {:ok, parsed}
        _ -> {:error, "Invalid integer value for #{column.label}"}
      end
    else
      case Float.parse(normalized) do
        {parsed, ""} -> {:ok, parsed}
        _ -> {:error, "Invalid numeric value for #{column.label}"}
      end
    end
  end

  defp parse_date_value(value, column) do
    normalized = String.trim(to_string(value))

    case Date.from_iso8601(normalized) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _reason} -> {:error, "Invalid date value for #{column.label}"}
    end
  end

  defp parse_datetime_value(value, column) do
    normalized =
      value
      |> to_string()
      |> String.trim()
      |> String.replace("T", " ")
      |> normalize_datetime_string()

    case NaiveDateTime.from_iso8601(normalized) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _reason} -> {:error, "Invalid datetime value for #{column.label}"}
    end
  end

  defp parse_time_value(value, column) do
    normalized =
      value
      |> to_string()
      |> String.trim()
      |> normalize_time_string()

    case Time.from_iso8601(normalized) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _reason} -> {:error, "Invalid time value for #{column.label}"}
    end
  end

  defp normalize_datetime_string(value) do
    if Regex.match?(~r/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/, value) do
      value <> ":00"
    else
      value
    end
  end

  defp normalize_time_string(value) do
    if Regex.match?(~r/^\d{2}:\d{2}$/, value) do
      value <> ":00"
    else
      value
    end
  end

  defp operator_requires_value?(operator) do
    normalize_operator(operator) not in ["is_null", "is_not_null"]
  end

  defp find_column(_available_columns, nil), do: nil

  defp find_column(available_columns, column_ref) do
    Enum.find(available_columns, &(&1.id == column_ref))
  end

  defp normalize_sort_column_ref(sort_column_ref, selected_columns, available_columns) do
    valid_ids = MapSet.new(Enum.map(available_columns, & &1.id))

    cond do
      is_binary(sort_column_ref) and MapSet.member?(valid_ids, sort_column_ref) ->
        sort_column_ref

      selected_columns != [] ->
        Enum.find(selected_columns, &MapSet.member?(valid_ids, &1))

      true ->
        case List.first(available_columns) do
          nil -> nil
          column -> column.id
        end
    end
  end

  defp normalize_sort_direction(direction) when direction in ["asc", "desc"], do: direction
  defp normalize_sort_direction(_), do: "asc"

  defp column_type_kind(nil), do: :other

  defp column_type_kind(data_type) do
    normalized = String.downcase(to_string(data_type))

    cond do
      normalized in ["text", "character varying", "character", "citext"] ->
        :text

      normalized in ["boolean"] ->
        :boolean

      normalized in [
        "smallint",
        "integer",
        "bigint",
        "numeric",
        "decimal",
        "real",
        "double precision"
      ] ->
        :number

      normalized == "date" ->
        :date

      normalized in ["timestamp without time zone", "timestamp with time zone"] ->
        :datetime

      normalized in ["time without time zone", "time with time zone"] ->
        :time

      true ->
        :other
    end
  end

  defp integer_data_type?(data_type) do
    normalized = String.downcase(to_string(data_type))
    normalized in ["smallint", "integer", "bigint"]
  end

  defp normalize_total_rows(value) when is_integer(value), do: value

  defp normalize_total_rows(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> 0
    end
  end

  defp normalize_total_rows(_), do: 0

  defp compute_total_pages(total_rows, _page_size) when total_rows <= 0, do: 0

  defp compute_total_pages(total_rows, page_size) do
    div(total_rows - 1, page_size) + 1
  end

  defp clamp_query_page(page, total_pages) when total_pages <= 0 do
    max(page, 1)
  end

  defp clamp_query_page(page, total_pages) do
    page
    |> max(1)
    |> min(total_pages)
  end

  defp display_total_pages(total_pages) when total_pages <= 0, do: 1
  defp display_total_pages(total_pages), do: total_pages

  defp query_builder_error_message([]), do: nil

  defp query_builder_error_message(errors) do
    messages = errors |> Enum.reverse() |> Enum.uniq() |> Enum.join(" | ")
    "Some columns could not be loaded: #{messages}"
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
