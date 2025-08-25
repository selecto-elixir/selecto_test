defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use SelectoComponents.Form
  ###

  @impl true
  def mount(_params, _session, socket) do
    {module, domain, path} =
      case socket.assigns.live_action do
        :index -> {SelectoTest.PagilaDomain, SelectoTest.PagilaDomain.actors_domain(), "/pagila"}
        :stores -> {SelectoTest.PagilaDomain, SelectoTest.PagilaDomain.actors_domain(), "/pagila_stores"}  # Fallback to actors for now
        :films -> {SelectoTest.PagilaDomainFilms, SelectoTest.PagilaDomainFilms.domain(), "/pagila_films"}
      end

    # Use SelectoTest.Repo instead of raw Postgrex connection for production compatibility
    selecto = Selecto.configure(domain, SelectoTest.Repo)

    views = [
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
      {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
      {:graph, SelectoComponents.Views.Graph, "Graph View", %{drill_down: :detail}}
    ]

    state = get_initial_state(views, selecto)

    saved_views = module.get_view_names( path )

    socket =
      assign(socket,
        show_view_configurator: false,
        views: views,
        my_path: path,
        saved_view_module: SelectoTest.PagilaDomain,
        saved_view_context: path,

        ### For saved view links
        path: path,
        available_saved_views: saved_views
      )

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_event("toggle_show_view_configurator", _par, socket) do
    {:noreply, assign(socket, show_view_configurator: !socket.assigns.show_view_configurator)}
  end

  @impl true
  def handle_event("graph_drill_down", params, socket) do
    # Handle drill down from graph view by switching to detail view with filters
    # Extract the clicked data point information
    label = params["label"]
    value = params["value"]

    # Log the drill down event for debugging
    require Logger
    Logger.info("Graph drill down: label=#{label}, value=#{value}")

    # Get the current graph view configuration to find the drill down target
    selected_view = String.to_atom(socket.assigns.view_config.view_mode)
    
    {_, _, _, opt} =
      Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)

    new_view_mode = Map.get(opt, :drill_down, "detail") |> to_string()

    # Find the field to filter on - use the first x_axis field from the graph configuration
    graph_config = socket.assigns.view_config.views.graph
    x_axis_fields = Map.get(graph_config, :x_axis, [])
    
    filter_field = case x_axis_fields do
      [{_uuid, field, _config} | _] -> field
      [] -> "id"  # Fallback to a basic field
    end

    # Create a new filter based on the clicked data point
    newid = UUID.uuid4()
    conf = Selecto.field(socket.assigns.selecto, filter_field)

    {filter_value, filter_value2} = if conf != nil do
      case conf.type do
        x when x in [:utc_datetime, :naive_datetime] ->
          Selecto.Helpers.Date.val_to_dates(%{"value" => label, "value2" => ""})
        _ ->
          {label, ""}
      end
    else
      # If no field configuration found, default to string handling
      {label, ""}
    end

    # Get existing filters and add the new one
    existing_filters = Map.get(socket.assigns.used_params || %{}, "filters", %{})
    
    # Add the new filter to existing filters 
    updated_filters = Map.put(existing_filters, newid, %{
      "comp" => "=",
      "filter" => filter_field,
      "index" => "0",
      "section" => "filters", 
      "uuid" => newid,
      "value" => filter_value,
      "value2" => filter_value2
    })
    
    # Create view parameters to update both the view mode and filters
    view_params = Map.merge(socket.assigns.used_params || %{}, %{
      "view_mode" => new_view_mode,
      "filters" => updated_filters
    })

    Logger.info("Graph drill down: switched to #{new_view_mode}, added filter #{filter_field}=#{filter_value}")

    # Use the same pattern as agg_add_filters to properly update and re-render the view
    {:noreply, view_from_params(view_params, state_to_url(view_params, socket))}
  end

  @doc """
  Test Domain
  """
end
