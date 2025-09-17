defmodule SelectoTestWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_join.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("selecto_test.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("selecto_test.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("selecto_test.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("selecto_test.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("selecto_test.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Selecto Metrics
      summary("selecto.query.complete.duration",
        event_name: [:selecto, :query, :complete],
        measurement: :duration,
        unit: {:native, :millisecond},
        description: "Selecto query execution time",
        tags: [],
        tag_values: &(&1)
      ),
      summary("selecto.query.complete.execution_time",
        event_name: [:selecto, :query, :complete],
        measurement: :execution_time,
        unit: {:native, :millisecond},
        description: "Time spent executing the query",
        tags: [],
        tag_values: &(&1)
      ),
      counter("selecto.query.error.count",
        event_name: [:selecto, :query, :error],
        measurement: :count,
        description: "Number of query errors",
        tags: [],
        tag_values: &(&1)
      ),
      counter("selecto.cache.hit.count",
        event_name: [:selecto, :cache, :hit],
        measurement: :count,
        description: "Number of cache hits",
        tags: [],
        tag_values: &(&1)
      ),
      counter("selecto.cache.miss.count",
        event_name: [:selecto, :cache, :miss],
        measurement: :count,
        description: "Number of cache misses",
        tags: [],
        tag_values: &(&1)
      ),

      # VM Metrics

      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {SelectoTestWeb, :count_users, []}
    ]
  end
end
