defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use Phoenix.Component

  use SelectoComponents.ViewSelector
  ###

  @impl true
  def mount(_params, _session, socket) do
    selecto = Selecto.configure(SelectoTest.Repo, SelectoTest.PagilaDomain.domain())

    {:ok,
      assign(socket,
        selecto: selecto,
        show_view: false,

        ###
        executed: false,
        applied_view: nil,

        ### Build the view:
        view_config: %{

          view_mode: "aggregate",
          active_tab: "view",
          per_page: 30,
          page: 0,
          aggregate: Map.get(selecto.domain, :default_aggregate, []) |> set_defaults(),
          group_by: Map.get(selecto.domain, :default_group_by, []) |> set_defaults(),
          order_by: Map.get(selecto.domain, :default_order_by, []) |> set_defaults(),
          selected: Map.get(selecto.domain, :default_selected, []) |> set_defaults(),
          filters: []
        }
      )}
  end


  @impl true
  def handle_params(_params, _uri, socket) do

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
  def handle_event("toggle_show_view", _par, socket) do
    {:noreply, assign(socket, show_view: !socket.assigns.show_view)}
  end

  @doc """
  Test Domain
  """

end
