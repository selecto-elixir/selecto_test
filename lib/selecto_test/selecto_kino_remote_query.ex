defmodule SelectoTest.SelectoKino.RemoteQuery do
  @moduledoc """
  Handles advanced Selecto query execution on the SelectoTest application.
  This module provides the server-side functionality for SelectoKino's app connection feature.
  """

  def execute_advanced_query(domain_name, query_params) do
    try do
      # Get the domain configuration
      domain_config = get_domain_config(domain_name)

      # Build Selecto query with advanced parameters
      selecto = Selecto.new(SelectoTest.Repo, domain_config)

      # Apply selected columns
      selecto = if query_params[:selected] && length(query_params[:selected]) > 0 do
        Selecto.select(selecto, query_params[:selected])
      else
        selecto
      end

      # Apply joins
      selecto = if query_params[:joins] && length(query_params[:joins]) > 0 do
        Enum.reduce(query_params[:joins], selecto, fn join, acc ->
          Selecto.join(acc, String.to_atom(join))
        end)
      else
        selecto
      end

      # Apply filters
      selecto = if query_params[:filters] && map_size(query_params[:filters]) > 0 do
        Enum.reduce(query_params[:filters], selecto, fn {field, condition}, acc ->
          apply_filter(acc, field, condition)
        end)
      else
        selecto
      end

      # Apply group by
      selecto = if query_params[:group_by] && length(query_params[:group_by]) > 0 do
        Selecto.group_by(selecto, query_params[:group_by])
      else
        selecto
      end

      # Apply order by
      selecto = if query_params[:order_by] && length(query_params[:order_by]) > 0 do
        Selecto.order_by(selecto, query_params[:order_by])
      else
        selecto
      end

      # Apply limit
      selecto = if query_params[:limit] && query_params[:limit] > 0 do
        Selecto.limit(selecto, query_params[:limit])
      else
        selecto
      end

      # Execute the query and return results
      results = Selecto.all(selecto)
      {:ok, results}

    rescue
      error -> {:error, "Query execution failed: #{inspect(error)}"}
    end
  end

  defp get_domain_config("actors"), do: SelectoTest.PagilaDomain.actors_domain()
  defp get_domain_config("films"), do: SelectoTest.PagilaDomainFilms.domain()
  defp get_domain_config(domain), do: raise("Unknown domain: #{domain}")

  defp apply_filter(selecto, field, condition) when is_map(condition) do
    case condition do
      %{"=" => value} -> Selecto.where(selecto, [{String.to_atom(field), :==, value}])
      %{">" => value} -> Selecto.where(selecto, [{String.to_atom(field), :>, value}])
      %{">=" => value} -> Selecto.where(selecto, [{String.to_atom(field), :>=, value}])
      %{"<" => value} -> Selecto.where(selecto, [{String.to_atom(field), :<, value}])
      %{"<=" => value} -> Selecto.where(selecto, [{String.to_atom(field), :<=, value}])
      %{"like" => value} -> Selecto.where(selecto, [{String.to_atom(field), :like, value}])
      %{"ilike" => value} -> Selecto.where(selecto, [{String.to_atom(field), :ilike, value}])
      %{"in" => values} when is_list(values) -> Selecto.where(selecto, [{String.to_atom(field), :in, values}])
      %{"between" => [min, max]} ->
        selecto
        |> Selecto.where([{String.to_atom(field), :>=, min}])
        |> Selecto.where([{String.to_atom(field), :<=, max}])
      _ -> selecto  # Skip unknown conditions
    end
  end

  defp apply_filter(selecto, field, value) do
    # Simple equality filter
    Selecto.where(selecto, [{String.to_atom(field), :==, value}])
  end
end
