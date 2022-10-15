defmodule ListableTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      ListableTest.Repo,
      # Start the Telemetry supervisor
      ListableTestWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ListableTest.PubSub},
      # Start the Endpoint (http/https)
      ListableTestWeb.Endpoint
      # Start a worker by calling: ListableTest.Worker.start_link(arg)
      # {ListableTest.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ListableTest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ListableTestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
