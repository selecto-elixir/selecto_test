defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use Phoenix.Component

  use SelectoComponents.ViewSelector
  ###

  def linker(t) do
    IO.inspect(t)
    ~p"/pagila"
  end

  @impl true
  def mount(_params, _session, socket) do
    IO.inspect(socket)
    selecto = Selecto.configure(SelectoTest.Repo, SelectoTest.PagilaDomain.domain())
    state = get_initial_state(selecto)

    socket = assign(socket, show_view_configurator: false )
    {:ok, assign(socket, state)}
  end



  @impl true
  def handle_params(_params, _uri, socket) do

    ### Handle page



    # socket =
    #   assign(socket,
    #     ### required for selecto components

    #     view_mode: params["view_mode"] || "detail",
    #     active_tab: params["active_tab"] || "view",
    #     per_page:
    #       if params["per_page"] do
    #         String.to_integer(params["per_page"])
    #       else
    #         30
    #       end,
    #     page:
    #       if params["page"] do
    #         String.to_integer(params["page"])
    #       else
    #         0
    #       end
    #   )

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_show_view_configurator", _par, socket) do
    {:noreply, assign(socket, show_view_configurator: !socket.assigns.show_view_configurator)}
  end

  @doc """
  Test Domain
  """
end
