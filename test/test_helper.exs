# Configure test environment
Application.put_env(:ex_unit, :capture_log, true)

# Increase timeout and allow parallelization while maintaining stability
ExUnit.start(
  timeout: 120_000,
  max_cases: System.schedulers_online(),
  capture_log: true,
  exclude: [:skip, :pending]
)

Ecto.Adapters.SQL.Sandbox.mode(SelectoTest.Repo, :manual)
