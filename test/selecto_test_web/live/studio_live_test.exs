defmodule SelectoTestWeb.StudioLiveTest do
  use SelectoTestWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL
  alias SelectoTest.JoinConfigStore
  alias SelectoTest.Repo

  @posts_author_join_id "fk_studio_lv_posts_author|public.studio_lv_posts|public.studio_lv_authors"
  @comments_post_join_id "fk_studio_lv_comments_post|public.studio_lv_comments|public.studio_lv_posts"

  setup do
    clear_saved_configs()
    create_join_fixture_tables()
    :ok
  end

  test "adds multi-hop joins and removes disconnected children", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/studio")

    assert has_element?(view, "#table-public-studio-lv-authors")

    view
    |> element("#table-public-studio-lv-authors")
    |> render_click()

    posts_join_dom_id = dom_id(@posts_author_join_id)
    comments_join_dom_id = dom_id(@comments_post_join_id)

    assert has_element?(view, "#add-join-#{posts_join_dom_id}")
    refute has_element?(view, "#selected-join-#{posts_join_dom_id}")

    view
    |> element("#add-join-#{posts_join_dom_id}")
    |> render_click()

    assert has_element?(view, "#selected-join-#{posts_join_dom_id}")
    assert has_element?(view, "#add-join-#{comments_join_dom_id}")

    view
    |> element("#add-join-#{comments_join_dom_id}")
    |> render_click()

    assert has_element?(view, "#selected-join-#{comments_join_dom_id}")

    view
    |> element("#remove-join-#{posts_join_dom_id}")
    |> render_click()

    refute has_element?(view, "#selected-join-#{posts_join_dom_id}")
    refute has_element?(view, "#selected-join-#{comments_join_dom_id}")
    assert has_element?(view, "#add-join-#{posts_join_dom_id}")
  end

  test "saves, loads, and deletes configs in ets", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/studio")

    view
    |> element("#table-public-studio-lv-authors")
    |> render_click()

    posts_join_dom_id = dom_id(@posts_author_join_id)
    comments_join_dom_id = dom_id(@comments_post_join_id)

    view
    |> element("#add-join-#{posts_join_dom_id}")
    |> render_click()

    view
    |> element("#add-join-#{comments_join_dom_id}")
    |> render_click()

    view
    |> element("#add-filter-button")
    |> render_click()

    query_params = %{
      "query" => %{
        "selected_columns" => [
          "public|studio_lv_authors|name",
          "public|studio_lv_comments|body"
        ],
        "sort_column_ref" => "public|studio_lv_comments|id",
        "sort_direction" => "asc",
        "filters" => %{
          "f1" => %{
            "column_ref" => "public|studio_lv_comments|id",
            "operator" => "gt",
            "value" => "99"
          }
        }
      }
    }

    view
    |> form("#query-builder-form", query_params)
    |> render_change()

    view
    |> form("#save-config-form", %{"save" => %{"name" => "Authors to comments"}})
    |> render_change()

    view
    |> form("#save-config-form")
    |> render_submit()

    saved =
      JoinConfigStore.list_configs()
      |> Enum.find(&(&1.name == "Authors to comments"))

    assert saved

    assert saved.selected_columns == [
             "public|studio_lv_authors|name",
             "public|studio_lv_comments|body"
           ]

    assert Enum.any?(saved.filters, fn filter ->
             filter.id == "f1" and
               filter.column_ref == "public|studio_lv_comments|id" and
               filter.operator == "gt" and
               filter.value == "99"
           end)

    assert saved.query_page_size == 25

    saved_dom_id = dom_id(saved.id)

    assert has_element?(view, "#saved-config-#{saved_dom_id}")
    assert has_element?(view, "#selected-join-#{posts_join_dom_id}")
    assert has_element?(view, "#selected-join-#{comments_join_dom_id}")

    view
    |> element("#remove-join-#{posts_join_dom_id}")
    |> render_click()

    refute has_element?(view, "#selected-join-#{posts_join_dom_id}")
    refute has_element?(view, "#selected-join-#{comments_join_dom_id}")

    view
    |> element("#load-saved-#{saved_dom_id}")
    |> render_click()

    assert has_element?(view, "#selected-join-#{posts_join_dom_id}")
    assert has_element?(view, "#selected-join-#{comments_join_dom_id}")
    assert has_element?(view, "#query-col-public-studio-lv-authors-name[checked]")
    assert has_element?(view, "#query-col-public-studio-lv-comments-body[checked]")
    assert has_element?(view, "#filter-row-f1")
    assert has_element?(view, "#filter-operator-f1 option[value=gt][selected]")
    assert has_element?(view, "#filter-value-f1")
    assert render(view) =~ "value=\"99\""

    view
    |> element("#delete-saved-#{saved_dom_id}")
    |> render_click()

    refute has_element?(view, "#saved-config-#{saved_dom_id}")
    assert JoinConfigStore.list_configs() == []
  end

  test "runs joined query with selected columns and filters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/studio")

    view
    |> element("#table-public-studio-lv-authors")
    |> render_click()

    posts_join_dom_id = dom_id(@posts_author_join_id)
    comments_join_dom_id = dom_id(@comments_post_join_id)

    view
    |> element("#add-join-#{posts_join_dom_id}")
    |> render_click()

    view
    |> element("#add-join-#{comments_join_dom_id}")
    |> render_click()

    view
    |> element("#add-filter-button")
    |> render_click()

    assert has_element?(view, "#filter-row-f1")

    query_params = %{
      "query" => %{
        "selected_columns" => [
          "public|studio_lv_authors|name",
          "public|studio_lv_comments|body"
        ],
        "sort_column_ref" => "public|studio_lv_comments|body",
        "sort_direction" => "asc",
        "filters" => %{
          "f1" => %{
            "column_ref" => "public|studio_lv_comments|body",
            "operator" => "eq",
            "value" => "great read"
          }
        }
      }
    }

    view
    |> form("#query-builder-form", query_params)
    |> render_change()

    view
    |> form("#query-builder-form", query_params)
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#joined-results-table")
    assert has_element?(view, "#joined-query-sql")

    html = render(view)

    assert html =~ "Ada Lovelace"
    assert html =~ "great read"
  end

  test "type-aware numeric filters reject invalid values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/studio")

    view
    |> element("#table-public-studio-lv-authors")
    |> render_click()

    posts_join_dom_id = dom_id(@posts_author_join_id)
    comments_join_dom_id = dom_id(@comments_post_join_id)

    view
    |> element("#add-join-#{posts_join_dom_id}")
    |> render_click()

    view
    |> element("#add-join-#{comments_join_dom_id}")
    |> render_click()

    view
    |> element("#add-filter-button")
    |> render_click()

    invalid_params = %{
      "query" => %{
        "selected_columns" => ["public|studio_lv_comments|id"],
        "sort_column_ref" => "public|studio_lv_comments|id",
        "sort_direction" => "asc",
        "filters" => %{
          "f1" => %{
            "column_ref" => "public|studio_lv_comments|id",
            "operator" => "gt",
            "value" => "abc"
          }
        }
      }
    }

    refute has_element?(view, "#filter-operator-f1 option[value=contains]")

    view
    |> form("#query-builder-form", invalid_params)
    |> render_change()

    view
    |> form("#query-builder-form", invalid_params)
    |> render_submit()

    render_async(view)

    assert render(view) =~ "Invalid integer value"
  end

  test "supports sorting and pagination", %{conn: conn} do
    insert_comment_range(101, 135)

    {:ok, view, _html} = live(conn, ~p"/studio")

    view
    |> element("#table-public-studio-lv-authors")
    |> render_click()

    posts_join_dom_id = dom_id(@posts_author_join_id)
    comments_join_dom_id = dom_id(@comments_post_join_id)

    view
    |> element("#add-join-#{posts_join_dom_id}")
    |> render_click()

    view
    |> element("#add-join-#{comments_join_dom_id}")
    |> render_click()

    query_params = %{
      "query" => %{
        "selected_columns" => [
          "public|studio_lv_comments|id",
          "public|studio_lv_comments|body"
        ],
        "sort_column_ref" => "public|studio_lv_comments|id",
        "sort_direction" => "asc",
        "filters" => %{}
      }
    }

    view
    |> form("#query-builder-form", query_params)
    |> render_change()

    view
    |> form("#query-builder-form", query_params)
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#query-page-indicator", "Page 1 / 2")
    refute render(view) =~ "note-130"

    view
    |> element("#query-next-page")
    |> render_click()

    render_async(view)

    assert has_element?(view, "#query-page-indicator", "Page 2 / 2")
    assert render(view) =~ "note-130"

    view
    |> element("#query-prev-page")
    |> render_click()

    render_async(view)

    assert has_element?(view, "#query-page-indicator", "Page 1 / 2")
  end

  test "imports full config json and restores query state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/studio")

    import_json =
      Jason.encode!(%{
        version: 1,
        base_table: "public.studio_lv_authors",
        selected_join_ids: [@posts_author_join_id, @comments_post_join_id],
        selected_columns: ["public|studio_lv_authors|name", "public|studio_lv_comments|id"],
        filters: [
          %{
            id: "f1",
            column_ref: "public|studio_lv_comments|id",
            operator: "gt",
            value: "99"
          }
        ],
        sort: %{column_ref: "public|studio_lv_comments|id", direction: "desc"},
        page_size: 50
      })

    view
    |> form("#import-config-form", %{"import" => %{"json" => import_json}})
    |> render_change()

    view
    |> form("#import-config-form")
    |> render_submit()

    posts_join_dom_id = dom_id(@posts_author_join_id)
    comments_join_dom_id = dom_id(@comments_post_join_id)

    assert has_element?(view, "#selected-join-#{posts_join_dom_id}")
    assert has_element?(view, "#selected-join-#{comments_join_dom_id}")
    assert has_element?(view, "#query-col-public-studio-lv-authors-name[checked]")
    assert has_element?(view, "#query-col-public-studio-lv-comments-id[checked]")
    assert has_element?(view, "#filter-row-f1")
    assert has_element?(view, "#sort-direction-select option[value=desc][selected]")
    assert has_element?(view, "#query-page-size option[value='50'][selected]")
  end

  test "pushes csv download events for current page and all rows", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/studio")

    view
    |> element("#table-public-studio-lv-authors")
    |> render_click()

    posts_join_dom_id = dom_id(@posts_author_join_id)
    comments_join_dom_id = dom_id(@comments_post_join_id)

    view
    |> element("#add-join-#{posts_join_dom_id}")
    |> render_click()

    view
    |> element("#add-join-#{comments_join_dom_id}")
    |> render_click()

    query_params = %{
      "query" => %{
        "selected_columns" => ["public|studio_lv_authors|name", "public|studio_lv_comments|body"],
        "sort_column_ref" => "public|studio_lv_comments|id",
        "sort_direction" => "asc",
        "page_size" => "25",
        "filters" => %{}
      }
    }

    view
    |> form("#query-builder-form", query_params)
    |> render_change()

    view
    |> form("#query-builder-form", query_params)
    |> render_submit()

    render_async(view)

    view
    |> element("#download-csv-page")
    |> render_click()

    assert_push_event(view, "download_csv", %{
      filename: "studio_query_page_1.csv",
      content: page_csv
    })

    assert page_csv =~ "public__studio_lv_authors__name"
    assert page_csv =~ "Ada Lovelace"

    view
    |> element("#download-csv-all")
    |> render_click()

    assert_push_event(view, "download_csv", %{filename: "studio_query_all.csv", content: all_csv})
    assert all_csv =~ "public__studio_lv_comments__body"
  end

  defp clear_saved_configs do
    JoinConfigStore.list_configs()
    |> Enum.each(fn config ->
      :ok = JoinConfigStore.delete_config(config.id)
    end)
  end

  defp create_join_fixture_tables do
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
      "insert into studio_lv_comments (id, post_id, body) values (100, 10, 'great read')",
      []
    )
  end

  defp insert_comment_range(from_id, to_id) do
    SQL.query!(
      Repo,
      """
      insert into studio_lv_comments (id, post_id, body)
      select gs, 10, 'note-' || gs::text
      from generate_series($1::integer, $2::integer) as gs
      """,
      [from_id, to_id]
    )
  end

  defp dom_id(value) when is_binary(value) do
    normalized =
      value
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    if normalized == "", do: "item", else: normalized
  end
end
