# Selecto Test Project

This project is a test/development project for the Selecto ecosystem modules. 

This project includes the complete Selecto ecosystem in the vendor directory:
- [selecto](https://github.com/selecto-elixir/selecto) - Core query builder
- [selecto_components](https://github.com/selecto-elixir/selecto_components) - Phoenix LiveView components
- [selecto_dome](https://github.com/selecto-elixir/selecto_dome) - Data manipulation interface
- [selecto_mix](https://github.com/selecto-elixir/selecto_mix) - Mix tasks and code generation
- **selecto_dev** - Development tools and dashboard (new!)

## Live Views

- `/` and `/pagila` - Actor-focused interface for [Pagila database](https://github.com/devrimgunduz/pagila)
- `/pagila_films` - Film-centric interface with ratings and categories
- `/pagila/film/:film_id` - Individual film detail pages

## Development Tools

- `/dev/dashboard` - Phoenix LiveDashboard for system metrics
- `/selecto_dev` - **SelectoDev Dashboard** with real-time monitoring:
  - Compilation tracking across all Selecto modules
  - Query performance analysis and debugging
  - Error tracking and analysis
  - Multi-project monitoring

## Additional Features

- **Livebook Integration** - Interactive notebooks in `notebooks/` directory
- **Comprehensive Testing** - 30+ test files covering all functionality
- **Development Scripts** - Helper utilities in `scripts/` directory

## Requirements

Projects using selecto_components should include Tailwind and Alpine.js as is done in this project. You also need to add the push event hook from assets/js/hooks.

## Setup

1. **Clone dependencies** (if not already present in vendor/):
   ```bash
   # All Selecto modules should be in vendor/ directory
   git clone <selecto-repo> vendor/selecto
   git clone <selecto-components-repo> vendor/selecto_components
   # etc.
   ```

2. **Install dependencies**:
   ```bash
   mix deps.get
   ```

3. **Setup database**:
   ```bash
   mix ecto.create
   mix ecto.migrate
   mix run priv/repo/seeds.exs
   ```

4. **Add Pagila data** (optional):
   - Download the [Pagila database](https://github.com/devrimgunduz/pagila)
   - Import tables and data into your dev database

5. **Start the application**:
   ```bash
   # For regular development
   mix phx.server
   
   # For Livebook connection (with named node)
   iex --sname selecto --cookie COOKIE -S mix phx.server
   ```

## Accessing the Dashboard

- **Main App**: http://localhost:4000
- **SelectoDev Dashboard**: http://localhost:4000/selecto_dev
- **Phoenix LiveDashboard**: http://localhost:4000/dev/dashboard

## Development Workflow

Use the integrated SelectoDev dashboard for:
- Real-time compilation monitoring
- Query performance analysis
- Error tracking and debugging
- Multi-project status overview

The dashboard provides a comprehensive development environment specifically tailored for Selecto ecosystem development.

