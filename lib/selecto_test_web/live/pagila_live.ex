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
        
        # Filter sets adapter
        filter_sets_adapter: SelectoTest.FilterSets,
        user_id: "demo_user", # In a real app, this would come from the session
        domain: path,

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
  def handle_info({:apply_filter_set, filter_set}, socket) do
    # Convert the saved filters from the filter set into the view_config format
    filters = filter_set.filters
    |> Enum.map(fn {uuid, filter_data} ->
      {uuid, "filters", filter_data}
    end)

    # Update the view_config with the loaded filters
    view_config = Map.put(socket.assigns.view_config, :filters, filters)

    {:noreply,
     socket
     |> assign(view_config: view_config)
     |> assign(page_title: "View: #{filter_set.name}")}
  end

  @doc """
  Test Domain
  """
end
