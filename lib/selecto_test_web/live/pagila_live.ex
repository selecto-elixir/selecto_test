defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use SelectoComponents.Form
  ###

  @impl true
  def mount(_params, _session, socket) do
    selecto = Selecto.configure(SelectoTest.Repo, SelectoTest.PagilaDomain.domain())
    state = get_initial_state(selecto)

    socket = assign(socket,
      show_view_configurator: false,
      my_path: "/pagila"
    )
    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_event("toggle_show_view_configurator", _par, socket) do
    {:noreply, assign(socket, show_view_configurator: !socket.assigns.show_view_configurator)}
  end

  @doc """
  Test Domain
  """
end
