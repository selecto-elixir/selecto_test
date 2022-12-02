defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use Phoenix.Component

  use SelectoComponents.ViewSelector
  ###

  @impl true
  def mount(_params, _session, socket) do
    selecto = Selecto.configure(SelectoTest.Repo, SelectoTest.PagilaDomain.domain())

    {:ok, assign(socket, selecto: selecto, show_view: false)}
  end

  @impl true
  def handle_event("toggle_show_view", _par, socket) do
    {:noreply, assign(socket, show_view: !socket.assigns.show_view)}
  end

  @doc """
  Test Domain
  """

end
