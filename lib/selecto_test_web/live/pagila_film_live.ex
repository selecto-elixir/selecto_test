defmodule SelectoTestWeb.PagilaFilmLive do

  use SelectoTestWeb, :live_view

  def render(assigns) do
    ~H"""
      <div>
        Focus on film: <%= @film_id %>
      </div>
    """
  end

  def mount(params, _session, socket) do
    socket =
      assign(socket,
        :film_id, params["film_id"]
      )

    {:ok, socket}
  end

end
