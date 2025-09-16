# Test script to verify saved view loading
# Run with: mix run test_saved_view_loading.exs

alias SelectoTest.Repo
alias SelectoTest.SavedViewConfig

IO.puts("\n=== Testing Saved View Loading ===\n")

# Get the test saved view
case Repo.get_by(SavedViewConfig, name: "test", context: "/pagila", view_type: "detail") do
  nil ->
    IO.puts("❌ No saved view found with name 'test'")

  config ->
    IO.puts("✅ Found saved view 'test'")
    IO.puts("\nView configuration:")
    IO.inspect(config.params, pretty: true, limit: :infinity)

    # Check the detail view config
    detail_config = config.params["detail"] || config.params[:detail]

    if detail_config do
      selected = detail_config["selected"] || detail_config[:selected] || []
      IO.puts("\n📋 Saved columns (#{length(selected)} total):")

      Enum.each(selected, fn
        [_uuid, field, _data] ->
          IO.puts("  • #{field}")
        {_uuid, field, _data} ->
          IO.puts("  • #{field}")
        _ ->
          IO.puts("  • (unknown format)")
      end)
    else
      IO.puts("\n⚠️  No detail configuration found in saved view")
    end
end

IO.puts("\n=== End Test ===\n")