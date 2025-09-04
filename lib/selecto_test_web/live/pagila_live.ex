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

    # Configure Selecto to use the main Repo connection pool
    selecto = Selecto.configure(domain, SelectoTest.Repo)

    views = [
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
      {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
      {:graph, SelectoComponents.Views.Graph, "Graph View", %{}}
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
    # Convert graph drill-down to the same format as aggregate drill-down
    # by delegating to the agg_add_filters handler
    %{"label" => label} = params
    
    # Get the x-axis field from the current selecto configuration
    x_axis_groups = socket.assigns.selecto.set[:x_axis_groups] || []
    
    case x_axis_groups do
      [{field_config, _field_spec} | _] ->
        # Build filter params in the same format as aggregate view
        field = field_config[:colid] || field_config[:field]
        filter_params = %{field => label}
        
        # Delegate to the agg_add_filters handler from SelectoComponents.Form
        handle_event("agg_add_filters", filter_params, socket)
        
      _ ->
        # No x-axis configured, ignore drill down
        {:noreply, socket}
    end
  end

  @impl true  
  def handle_event("chart_click", params, socket) do
    # Also handle chart_click event (in case it comes through with that name)
    handle_event("graph_drill_down", params, socket)
  end

  @doc """
  Test Domain
  """
end
