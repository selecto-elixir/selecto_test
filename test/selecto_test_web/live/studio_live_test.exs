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
    |> form("#save-config-form", %{"save" => %{"name" => "Authors to comments"}})
    |> render_change()

    view
    |> form("#save-config-form")
    |> render_submit()

    saved =
      JoinConfigStore.list_configs()
      |> Enum.find(&(&1.name == "Authors to comments"))

    assert saved

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

    view
    |> element("#delete-saved-#{saved_dom_id}")
    |> render_click()

    refute has_element?(view, "#saved-config-#{saved_dom_id}")
    assert JoinConfigStore.list_configs() == []
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

  defp dom_id(value) when is_binary(value) do
    normalized =
      value
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    if normalized == "", do: "item", else: normalized
  end
end
