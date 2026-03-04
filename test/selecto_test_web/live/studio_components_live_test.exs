defmodule SelectoTestWeb.StudioComponentsLiveTest do
  use SelectoTestWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL
  alias SelectoTest.Repo

  @posts_author_join_id "fk_studio_lv_posts_author|public.studio_lv_posts|public.studio_lv_authors"
  @comments_post_join_id "fk_studio_lv_comments_post|public.studio_lv_comments|public.studio_lv_posts"
  @links_author_join_id "fk_studio_lv_links_author|public.studio_lv_post_links|public.studio_lv_authors"

  setup do
    create_join_fixture_tables()
    :ok
  end

  test "loads aggregate and detail views from studio payload", %{conn: conn} do
    payload = %{
      "base_table" => "public.studio_lv_authors",
      "selected_joins" => [
        %{
          "id" => @posts_author_join_id,
          "join_type" => "left",
          "parent_schema" => "public",
          "parent_table" => "studio_lv_authors",
          "child_schema" => "public",
          "child_table" => "studio_lv_posts",
          "on" => [%{"parent_column" => "id", "child_column" => "author_id"}]
        },
        %{
          "id" => @comments_post_join_id,
          "join_type" => "inner",
          "parent_schema" => "public",
          "parent_table" => "studio_lv_posts",
          "child_schema" => "public",
          "child_table" => "studio_lv_comments",
          "on" => [%{"parent_column" => "id", "child_column" => "post_id"}]
        }
      ],
      "selected_columns" => [
        "public|studio_lv_authors|name",
        "public|studio_lv_posts|title",
        "public|studio_lv_comments|body"
      ],
      "filters" => [
        %{"column_ref" => "public|studio_lv_comments|id", "operator" => "gt", "value" => "99"}
      ],
      "sort_rules" => [
        %{"id" => "s1", "column_ref" => "public|studio_lv_comments|id", "direction" => "desc"}
      ]
    }

    encoded_payload =
      payload
      |> Jason.encode!()
      |> Base.url_encode64(padding: false)

    {:ok, view, html} = live(conn, ~p"/studio/components?payload=#{encoded_payload}")

    assert html =~ "Aggregate View"
    assert html =~ "Detail View"
    refute has_element?(view, "option[value='j1[film_id]']")
  end

  test "aggregate view works when joined table has no id column", %{conn: conn} do
    payload = %{
      "base_table" => "public.studio_lv_authors",
      "selected_joins" => [
        %{
          "id" => @links_author_join_id,
          "join_type" => "left",
          "parent_schema" => "public",
          "parent_table" => "studio_lv_authors",
          "child_schema" => "public",
          "child_table" => "studio_lv_post_links",
          "on" => [%{"parent_column" => "id", "child_column" => "author_id"}]
        }
      ],
      "selected_columns" => [
        "public|studio_lv_authors|name",
        "public|studio_lv_post_links|author_id"
      ]
    }

    encoded_payload =
      payload
      |> Jason.encode!()
      |> Base.url_encode64(padding: false)

    {:ok, view, _html} = live(conn, ~p"/studio/components?payload=#{encoded_payload}")

    params = %{
      "view_mode" => "aggregate",
      "group_by" => %{
        "g1" => %{"field" => "name", "format" => "default", "index" => "0", "alias" => ""}
      },
      "aggregate" => %{
        "a1" => %{
          "field" => "j1.author_id",
          "format" => "count",
          "index" => "0",
          "alias" => ""
        }
      },
      "aggregate_per_page" => "100",
      "prevent_denormalization" => "on",
      "count_mode" => "bounded",
      "per_page" => "30",
      "max_rows" => "1000"
    }

    _ = render_submit(view, "view-apply", params)

    live_state = :sys.get_state(view.pid)
    execution_error = live_state.socket.assigns.execution_error
    last_query_info = live_state.socket.assigns.last_query_info

    html = render(view)

    assert is_nil(execution_error), "execution_error: #{inspect(execution_error, pretty: true)}"
    assert is_binary(last_query_info.sql)
    refute html =~ "View cannot be displayed due to query error"
    refute html =~ "column j1.id does not exist"
  end

  defp create_join_fixture_tables do
    SQL.query!(Repo, "drop table if exists studio_lv_post_links", [])
    SQL.query!(Repo, "drop table if exists studio_lv_comments", [])
    SQL.query!(Repo, "drop table if exists studio_lv_posts", [])
    SQL.query!(Repo, "drop table if exists studio_lv_authors", [])

    SQL.query!(
      Repo,
      """
      create table studio_lv_authors (
        id integer primary key,
        name text not null
      )
      """,
      []
    )

    SQL.query!(
      Repo,
      """
      create table studio_lv_posts (
        id integer primary key,
        author_id integer not null,
        title text not null,
        constraint fk_studio_lv_posts_author foreign key (author_id) references studio_lv_authors (id)
      )
      """,
      []
    )

    SQL.query!(
      Repo,
      """
      create table studio_lv_post_links (
        author_id integer not null,
        film_id integer not null,
        constraint fk_studio_lv_links_author foreign key (author_id) references studio_lv_authors (id)
      )
      """,
      []
    )

    SQL.query!(
      Repo,
      """
      create table studio_lv_comments (
        id integer primary key,
        post_id integer not null,
        body text not null,
        constraint fk_studio_lv_comments_post foreign key (post_id) references studio_lv_posts (id)
      )
      """,
      []
    )

    SQL.query!(Repo, "insert into studio_lv_authors (id, name) values (1, 'Ada Lovelace')", [])

    SQL.query!(
      Repo,
      "insert into studio_lv_posts (id, author_id, title) values (10, 1, 'Analytical Engines')",
      []
    )

    SQL.query!(
      Repo,
      "insert into studio_lv_post_links (author_id, film_id) values (1, 10)",
      []
    )

    SQL.query!(
      Repo,
      "insert into studio_lv_comments (id, post_id, body) values (100, 10, 'great read')",
      []
    )
  end
end
