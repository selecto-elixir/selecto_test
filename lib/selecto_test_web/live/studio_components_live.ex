defmodule SelectoTestWeb.StudioComponentsLive do
  use SelectoTestWeb, :live_view

  use SelectoComponents.Form

  alias SelectoTest.Studio.ComponentsDomainBuilder

  @impl true
  def mount(params, _session, socket) do
    views = [
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
      {:detail, SelectoComponents.Views.Detail, "Detail View", %{}}
    ]

    with {:ok, payload} <- decode_payload(Map.get(params, "payload")),
         {:ok, selecto} <- ComponentsDomainBuilder.build_selecto(payload) do
      state =
        get_initial_state(views, selecto)
        |> sanitize_component_state()

      socket =
        socket
        |> assign(:page_title, "Studio Components")
        |> assign(:show_view_configurator, false)
        |> assign(:my_path, "/studio/components")
        |> assign(:path, "/studio/components")
        |> assign(:saved_view_module, nil)
        |> assign(:saved_view_context, "/studio/components")
        |> assign(:available_saved_views, [])

      {:ok, assign(socket, state)}
    else
      {:error, reason} ->
        fallback = Selecto.configure(SelectoTest.PagilaDomain.actors_domain(), SelectoTest.Repo)
        state = get_initial_state(views, fallback) |> sanitize_component_state()

        socket =
          socket
          |> put_flash(:error, "Could not open Studio config in components: #{reason}")
          |> assign(:page_title, "Studio Components")
          |> assign(:show_view_configurator, false)
          |> assign(:my_path, "/studio/components")
          |> assign(:path, "/studio/components")
          |> assign(:saved_view_module, nil)
          |> assign(:saved_view_context, "/studio/components")
          |> assign(:available_saved_views, [])

        {:ok, assign(socket, state)}
    end
  end

  defp decode_payload(nil), do: {:error, "missing payload"}

  defp decode_payload(encoded_payload) do
    with {:ok, decoded} <- Base.url_decode64(encoded_payload, padding: false),
         {:ok, payload} <- Jason.decode(decoded),
         true <- is_map(payload) do
      {:ok, payload}
    else
      _ -> {:error, "invalid payload"}
    end
  end

  defp sanitize_component_state(state) when is_list(state) do
    columns = Keyword.get(state, :columns, [])

    sanitized_columns =
      columns
      |> Enum.reject(fn {field_id, _name, _type} ->
        String.contains?(to_string(field_id), "[")
      end)

    Keyword.put(state, :columns, sanitized_columns)
  end
end
