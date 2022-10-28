defmodule SelectoTestWeb.DetailTestLive do
  use SelectoTestWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      assign(socket,
        selecto: Selecto.configure(SelectoTest.Repo, SelectoTest.selecto_domain())
      )

    {:noreply, socket}
  end
end
