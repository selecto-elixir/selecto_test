# Configure test environment
Application.put_env(:ex_unit, :capture_log, true)

# Determine which tests to exclude
exclude_tags = [:skip, :pending]

# Only run MySQL tests if TEST_MYSQL environment variable is set
unless System.get_env("TEST_MYSQL") do
  exclude_tags = exclude_tags ++ [:mysql_integration]
end

# Increase timeout and allow parallelization while maintaining stability
ExUnit.start(
  timeout: 120_000,
  max_cases: System.schedulers_online(),
  capture_log: true,
  exclude: exclude_tags
)

Ecto.Adapters.SQL.Sandbox.mode(SelectoTest.Repo, :manual)
