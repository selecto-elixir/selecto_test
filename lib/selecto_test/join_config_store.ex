defmodule SelectoTest.JoinConfigStore do
  @moduledoc false

  @type config_record :: map()

  @spec list_configs() :: [config_record()]
  defdelegate list_configs(), to: SelectoStudio.JoinConfigStore

  @spec save_config(map()) :: {:ok, config_record()} | {:error, term()}
  defdelegate save_config(attrs), to: SelectoStudio.JoinConfigStore

  @spec get_config(binary()) :: {:ok, config_record()} | :error
  defdelegate get_config(id), to: SelectoStudio.JoinConfigStore

  @spec delete_config(binary()) :: :ok
  defdelegate delete_config(id), to: SelectoStudio.JoinConfigStore
end
