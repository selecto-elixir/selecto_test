defmodule SelectoTest.SavedViewContextTest do
  use SelectoTest.DataCase, async: true

  defmodule TestDomain do
    use SelectoTest.SavedViewContext
  end

  test "list_views/1 returns saved views with metadata" do
    context = "/saved-view-context-test"

    _view_a = TestDomain.save_view("View A", context, %{"view_mode" => "detail"})
    _view_b = TestDomain.save_view("View B", context, %{"view_mode" => "aggregate"})

    views = TestDomain.list_views(context)
    names = Enum.map(views, & &1.name)

    assert "View A" in names
    assert "View B" in names
    assert Enum.all?(views, &(not is_nil(&1.updated_at)))
  end

  test "rename_view/3 renames an existing saved view" do
    context = "/saved-view-rename-test"
    _saved = TestDomain.save_view("Original Name", context, %{"view_mode" => "detail"})

    assert {:ok, renamed} = TestDomain.rename_view("Original Name", "Renamed View", context)
    assert renamed.name == "Renamed View"
    assert is_nil(TestDomain.get_view("Original Name", context))

    assert %SelectoTest.SavedView{name: "Renamed View"} =
             TestDomain.get_view("Renamed View", context)
  end

  test "delete_view/2 deletes an existing saved view" do
    context = "/saved-view-delete-test"
    _saved = TestDomain.save_view("Delete Me", context, %{"view_mode" => "detail"})

    assert {:ok, _deleted} = TestDomain.delete_view("Delete Me", context)
    assert is_nil(TestDomain.get_view("Delete Me", context))
  end

  test "rename_view/3 returns :already_exists when target name is taken" do
    context = "/saved-view-duplicate-name-test"

    _one = TestDomain.save_view("View One", context, %{"view_mode" => "detail"})
    _two = TestDomain.save_view("View Two", context, %{"view_mode" => "detail"})

    assert {:error, :already_exists} = TestDomain.rename_view("View One", "View Two", context)
  end
end
