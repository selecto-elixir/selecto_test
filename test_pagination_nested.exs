#!/usr/bin/env elixir

# Test script to verify nested table data updates correctly on pagination
# Run with: mix run test_pagination_nested.exs

require Logger

defmodule PaginationTest do
  def run do
    Logger.info("Testing pagination with nested tables...")
    
    # Build a Selecto query with denormalization prevention
    domain = SelectoTest.PagilaDomain.actors_domain()
    selecto = Selecto.configure(domain, SelectoTest.Repo)
    
    # Select columns that would cause denormalization
    columns_to_select = [
      %{"uuid" => "actor_name", "field" => "actor[first_name]"},
      %{"uuid" => "film_title", "field" => "film[title]"},
      %{"uuid" => "film_desc", "field" => "film[description]"}
    ]
    
    # Process with denormalization prevention
    params = %{
      "prevent_denormalization" => "true",
      "selected" => columns_to_select
    }
    
    Logger.info("Processing with params: #{inspect(params)}")
    
    # This simulates what the form component does
    selecto_with_denorm = SelectoComponents.Views.Detail.Process.apply(
      selecto,
      params,
      %{page: 0, per_page: 10}
    )
    
    Logger.info("Denormalization groups: #{inspect(Map.get(selecto_with_denorm.set, :denorm_groups))}")
    
    # Apply subselects
    selecto_with_subselects = 
      if Map.has_key?(selecto_with_denorm.set, :denorm_groups) and 
         is_map(selecto_with_denorm.set.denorm_groups) and 
         map_size(selecto_with_denorm.set.denorm_groups) > 0 do
        denorm_groups = selecto_with_denorm.set.denorm_groups
        Enum.reduce(denorm_groups, selecto_with_denorm, fn {relationship_path, columns}, acc ->
          SelectoComponents.SubselectBuilder.add_subselect_for_group(acc, relationship_path, columns)
        end)
      else
        selecto_with_denorm
      end
    
    # Execute query for page 1
    Logger.info("\n=== Page 1 Results ===")
    {results_p1, sql_p1} = Selecto.execute_with_sql(selecto_with_subselects)
    
    Logger.info("SQL: #{sql_p1}")
    Logger.info("Result count: #{length(elem(results_p1, 0))}")
    
    # Show first result structure
    if length(elem(results_p1, 0)) > 0 do
      {rows, fields, _aliases} = results_p1
      first_row = Enum.at(rows, 0)
      Logger.info("First row: #{inspect(first_row)}")
      Logger.info("Fields: #{inspect(fields)}")
    end
    
    # Now test page 2
    Logger.info("\n=== Page 2 Results (offset 10) ===")
    selecto_page2 = put_in(selecto_with_subselects.set[:offset], 10)
    {results_p2, sql_p2} = Selecto.execute_with_sql(selecto_page2)
    
    Logger.info("SQL: #{sql_p2}")
    Logger.info("Result count: #{length(elem(results_p2, 0))}")
    
    # Show first result of page 2
    if length(elem(results_p2, 0)) > 0 do
      {rows, fields, _aliases} = results_p2
      first_row = Enum.at(rows, 0)
      Logger.info("First row of page 2: #{inspect(first_row)}")
      
      # Check if film data is different
      film_data_p1 = case elem(results_p1, 0) do
        [row | _] -> 
          row_list = if is_tuple(row), do: Tuple.to_list(row), else: List.wrap(row)
          film_idx = Enum.find_index(fields, &(&1 == "film"))
          if film_idx, do: Enum.at(row_list, film_idx), else: nil
        _ -> nil
      end
      
      film_data_p2 = case elem(results_p2, 0) do
        [row | _] -> 
          row_list = if is_tuple(row), do: Tuple.to_list(row), else: List.wrap(row)
          film_idx = Enum.find_index(fields, &(&1 == "film"))
          if film_idx, do: Enum.at(row_list, film_idx), else: nil
        _ -> nil
      end
      
      Logger.info("\nFilm data from page 1: #{inspect(film_data_p1, limit: :infinity, pretty: true)}")
      Logger.info("\nFilm data from page 2: #{inspect(film_data_p2, limit: :infinity, pretty: true)}")
      
      if film_data_p1 == film_data_p2 do
        Logger.warn("WARNING: Film data is the same on both pages - pagination may not be working correctly!")
      else
        Logger.info("SUCCESS: Film data is different between pages - pagination is working!")
      end
    end
    
    :ok
  end
end

PaginationTest.run()