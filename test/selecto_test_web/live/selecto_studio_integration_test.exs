defmodule SelectoTestWeb.SelectoStudioIntegrationTest do
  use SelectoTestWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL
  alias SelectoTest.Repo

  setup do
    SQL.query!(Repo, "drop table if exists studio_host_integration_records", [])

    SQL.query!(
      Repo,
      """
      create table studio_host_integration_records (
        id integer primary key,
        label text not null
      )
      """,
      []
    )

    SQL.query!(
      Repo,
      "insert into studio_host_integration_records (id, label) values (1, 'integration-row')",
      []
    )

    :ok
  end

  test "mounts SelectoStudioWeb live routes with host repo wiring", %{conn: conn} do
    assert Application.fetch_env!(:selecto_studio, :repo) == SelectoTest.Repo

    assert Application.fetch_env!(:selecto_studio, :schema_explorer) ==
             SelectoStudio.SchemaExplorer

    assert Application.fetch_env!(:selecto_studio, :join_config_store) ==
             SelectoStudio.JoinConfigStore

    assert Phoenix.Router.route_info(SelectoTestWeb.Router, "GET", "/studio", "").log_module ==
             SelectoStudioWeb.StudioLive

    assert Phoenix.Router.route_info(SelectoTestWeb.Router, "GET", "/studio/components", "").log_module ==
             SelectoStudioWeb.StudioComponentsLive

    {:ok, view, html} = live(conn, ~p"/studio")

    assert html =~ "Selecto Studio"

    view
    |> element("#table-public-studio-host-integration-records")
    |> render_click()

    assert render(view) =~ "integration-row"
  end
end
