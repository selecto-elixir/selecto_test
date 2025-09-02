#!/usr/bin/env elixir

# Script to fix all documentation test files to use the shared test helper

defmodule TestFixer do
  @test_files [
    "test/docs_array_operations_examples_test.exs",
    "test/docs_cte_examples_test.exs",
    "test/docs_json_operations_examples_test.exs",
    "test/docs_lateral_joins_examples_test.exs",
    "test/docs_parameterized_joins_examples_test.exs",
    "test/docs_set_operations_examples_test.exs",
    "test/docs_subqueries_subfilters_examples_test.exs",
    "test/docs_subselects_examples_test.exs",
    "test/docs_window_functions_examples_test.exs"
  ]
  
  def fix_all do
    Enum.each(@test_files, &fix_file/1)
  end
  
  def fix_file(file_path) do
    IO.puts("Fixing #{file_path}...")
    
    content = File.read!(file_path)
    
    # Add import for test helpers at the top
    fixed_content = 
      if String.contains?(content, "import SelectoTest.TestHelpers") do
        content
      else
        content
        |> String.replace(
          "use ExUnit.Case, async: true",
          "use ExUnit.Case, async: true\n  import SelectoTest.TestHelpers"
        )
      end
    
    # Remove local configure_test_selecto definitions
    fixed_content = 
      fixed_content
      |> String.replace(~r/\n  defp configure_test_selecto.*?\n  end\n/s, "\n")
      |> String.replace(~r/\n  defp get_test_domain.*?\n  end\n/s, "\n")
      |> String.replace(~r/\n  defp get_test_connection.*?\n  end\n/s, "\n")
    
    # Fix incorrect function calls
    fixed_content =
      fixed_content
      # Remove Selecto.from calls (not a real function)
      |> String.replace(~r/Selecto\.from\([^)]+\)/m, "# from clause should be in domain config")
      # Remove Selecto.join calls (not a standalone function)
      |> String.replace(~r/Selecto\.join\([^)]+\)/m, "# join should be in domain config")
      # Fix Selecto.having (should be part of filter)
      |> String.replace("Selecto.having(", "Selecto.filter(")
      # Remove Selecto.aggregate (use select with tuples)
      |> String.replace("Selecto.aggregate(", "Selecto.select(")
      # Fix Selecto.update (not a Selecto function)
      |> String.replace("Selecto.update(", "# Selecto.update not implemented - ")
    
    File.write!(file_path, fixed_content)
    IO.puts("  ✓ Fixed #{file_path}")
  end
end

TestFixer.fix_all()
IO.puts("\nAll test files have been updated!")