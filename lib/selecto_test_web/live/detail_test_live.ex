defmodule SelectoTesttWeb.DetailTestLive do
  use SelectoTesttWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      assign(socket,
        selecto: selecto.configure(SelectoTestt.Repo, SelectoTestt.selecto_domain())
      )

    {:noreply, socket}
  end
end
