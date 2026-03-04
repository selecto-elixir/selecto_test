defmodule SelectoTest.JoinConfigStore do
  @moduledoc """
  Ephemeral ETS-backed storage for saved join configurations.

  This avoids requiring DB setup for config persistence in short-lived
  or containerized deployments.
  """

  use GenServer

  @table :selecto_test_join_configs

  @type config_record :: %{
          id: binary(),
          name: binary(),
          base_table: binary() | nil,
          selected_join_ids: [binary()],
          join_config_json: binary(),
          selecto_join_config: binary(),
          saved_at: DateTime.t(),
          saved_at_unix: integer()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @spec list_configs() :: [config_record()]
  def list_configs do
    if table_ready?() do
      @table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, config} -> config end)
      |> Enum.sort_by(& &1.saved_at_unix, :desc)
    else
      []
    end
  end

  @spec save_config(map()) :: {:ok, config_record()} | {:error, term()}
  def save_config(attrs) when is_map(attrs) do
    if table_ready?() do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      id = Ecto.UUID.generate()

      record = %{
        id: id,
        name: normalize_name(Map.get(attrs, :name), now),
        base_table: Map.get(attrs, :base_table),
        selected_join_ids: Map.get(attrs, :selected_join_ids, []),
        join_config_json: Map.get(attrs, :join_config_json, ""),
        selecto_join_config: Map.get(attrs, :selecto_join_config, ""),
        saved_at: now,
        saved_at_unix: DateTime.to_unix(now)
      }

      true = :ets.insert(@table, {id, record})
      {:ok, record}
    else
      {:error, :store_not_ready}
    end
  end

  @spec get_config(binary()) :: {:ok, config_record()} | :error
  def get_config(id) when is_binary(id) do
    if table_ready?() do
      case :ets.lookup(@table, id) do
        [{^id, config}] -> {:ok, config}
        [] -> :error
      end
    else
      :error
    end
  end

  @spec delete_config(binary()) :: :ok
  def delete_config(id) when is_binary(id) do
    if table_ready?() do
      :ets.delete(@table, id)
    end

    :ok
  end

  @impl true
  def init(:ok) do
    create_table()
    {:ok, %{}}
  end

  defp create_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _tid ->
        :ok
    end
  end

  defp table_ready? do
    :ets.whereis(@table) != :undefined
  end

  defp normalize_name(name, now) when is_binary(name) do
    trimmed = String.trim(name)

    if trimmed == "" do
      default_name(now)
    else
      trimmed
    end
  end

  defp normalize_name(_name, now), do: default_name(now)

  defp default_name(now) do
    "Join Config #{Calendar.strftime(now, "%Y-%m-%d %H:%M:%S UTC")}"
  end
end
