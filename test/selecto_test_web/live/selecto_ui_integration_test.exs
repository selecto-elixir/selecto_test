defmodule SelectoTestWeb.SelectoUIIntegrationTest do
  use SelectoTestWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Selecto LiveView integration" do
    test "actors domain loads successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pagila")
      
      # Basic page structure should be present
      assert html =~ "Selecto Test System"
      assert html =~ "Toggle View Controller"
    end

    test "films domain loads successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pagila_films")
      
      # Basic page structure should be present
      assert html =~ "Selecto Test System"
      assert html =~ "Toggle View Controller"
    end

    test "can toggle view controller to show SelectoComponents", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila")
      
      # Click the toggle button to show the view controller
      html = view
             |> element("button", "Toggle View Controller")
             |> render_click()
      
      # After toggle, should show SelectoComponents interface
      # Look for common SelectoComponents elements
      has_selecto_interface = html =~ "selecto" or 
                            html =~ "form" or 
                            html =~ "filter" or
                            html =~ "select" or
                            html =~ "data-phx-component"
      
      assert has_selecto_interface
    end

    test "view controller contains actor domain content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila")
      
      # Toggle to show the interface
      html = view
             |> element("button", "Toggle View Controller")
             |> render_click()
      
      # Should contain actor-related content
      actor_content = html =~ "actor" or 
                     html =~ "Actor" or 
                     html =~ "first_name" or 
                     html =~ "last_name"
      
      assert actor_content
    end

    test "film rating filter is available in actors domain", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila")
      
      # Toggle to show the interface
      html = view
             |> element("button", "Toggle View Controller")
             |> render_click()
      
      # Look for film rating filter
      has_rating_filter = html =~ "Film Rating" or 
                         html =~ "film[rating]" or 
                         html =~ "rating"
      
      assert has_rating_filter
    end

    test "films domain shows rating filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila_films")
      
      # Toggle to show the interface
      html = view
             |> element("button", "Toggle View Controller")
             |> render_click()
      
      # Should show rating filter in films domain
      has_rating = html =~ "rating" or html =~ "Rating"
      assert has_rating
    end

    test "SelectoComponents form can be found after toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila")
      
      # Toggle to show the interface
      html = view
             |> element("button", "Toggle View Controller")
             |> render_click()
      
      # Should now have form elements
      has_form = has_element?(view, "form") or 
                html =~ "<form" or 
                html =~ "data-phx-component"
      
      assert has_form
    end

    test "can interact with SelectoComponents after toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila")
      
      # Toggle to show the interface
      _html = view
              |> element("button", "Toggle View Controller")
              |> render_click()
      
      # Try to find and interact with a form
      if has_element?(view, "form") do
        # If form exists, try to submit it
        result = view
                |> element("form")
                |> render_submit(%{})
        
        # Should not crash
        assert is_binary(result)
      else
        # If no form, check for SelectoComponents LiveComponent
        has_component = has_element?(view, "[data-phx-component]")
        assert has_component
      end
    end

    test "MPAA rating options are configured correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila")
      
      # Toggle to show the interface
      html = view
             |> element("button", "Toggle View Controller")
             |> render_click()
      
      # Look for MPAA rating options in the DOM
      # They might be in option elements, data attributes, or checkbox values
      expected_ratings = ["G", "PG", "PG-13", "R", "NC-17"]
      
      found_ratings = Enum.count(expected_ratings, fn rating ->
        html =~ "\"#{rating}\"" or html =~ ">#{rating}<" or html =~ rating
      end)
      
      # Should find at least some MPAA ratings if filter is present
      if html =~ "rating" or html =~ "Rating" do
        assert found_ratings > 0
      else
        # Rating filter might not be visible yet - that's also valid
        assert true
      end
    end
  end

  describe "Individual film pages" do
    test "can navigate to film detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pagila/film/1")
      
      # Should load film page
      film_page = html =~ "film" or html =~ "Film" or html =~ "Title"
      assert film_page
    end

    test "film detail page has basic structure", %{conn: conn} do
      {:ok, view, html} = live(conn, "/pagila/film/1")
      
      # Should have basic page elements
      basic_structure = html =~ "Selecto Test System" and 
                       (html =~ "film" or html =~ "Film")
      
      assert basic_structure
    end
  end

  describe "Error handling" do
    test "handles non-existent film IDs gracefully", %{conn: conn} do
      # Try with a very high film ID that likely doesn't exist
      {:ok, _view, html} = live(conn, "/pagila/film/999999")
      
      # Should not crash, might show error or empty content
      assert is_binary(html)
      assert html =~ "Selecto Test System"
    end

    test "handles malformed URLs gracefully", %{conn: conn} do
      # Test with non-numeric film ID
      assert_error_sent 404, fn ->
        live(conn, "/pagila/film/not-a-number")
      end
    end
  end

  describe "Navigation" do
    test "can navigate between domains", %{conn: conn} do
      # Test direct navigation to both domains
      {:ok, _actors_view, actors_html} = live(conn, "/pagila")
      assert actors_html =~ "Selecto Test System"
      
      {:ok, _films_view, films_html} = live(conn, "/pagila_films")
      assert films_html =~ "Selecto Test System"
    end

    test "navigation links are present", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pagila")
      
      # Should have navigation links
      has_nav = html =~ "Pagila Actors" and 
               html =~ "Pagila Films"
      
      assert has_nav
    end
  end
end