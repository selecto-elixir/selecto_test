# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

**Setup and Dependencies:**
```bash
# Initial setup (includes deps.get, ecto.setup, assets setup/build)
mix setup

# Get dependencies only
mix deps.get

# Database operations
mix ecto.create
mix ecto.migrate
mix ecto.reset  # drops and recreates database
mix run priv/repo/seeds.exs
```

**Development Server:**
```bash
# Start Phoenix server (localhost only)
mix phx.server

# Start with IEx console (required for Livebook connection)
iex --sname selecto --cookie COOKIE -S mix phx.server

# Bind to all interfaces (0.0.0.0) for remote access
BIND_ALL_INTERFACES=true mix phx.server
BIND_ALL_INTERFACES=true iex --sname selecto --cookie COOKIE -S mix phx.server
```

**Assets:**
```bash
# Setup assets (Tailwind + esbuild)
mix assets.setup

# Build assets for development
mix assets.build

# Build and minify for production
mix assets.deploy
```

**Testing:**
```bash
# Run tests (includes database setup)
mix test
```

## Architecture Overview

This is a Phoenix LiveView application that serves as a test/development environment for the Selecto and SelectoComponents libraries. The app provides dynamic data visualization interfaces for the Pagila sample database.

**Important:** This project encompasses both the `selecto_test` application and the related projects in the `vendor/` directory (`selecto` and `selecto_components`). When making changes, you may need to modify code across multiple projects to maintain compatibility.

### Key Dependencies
- **Selecto & SelectoComponents**: Main libraries being tested, located in `vendor/` directory as git checkouts
- **Phoenix LiveView**: Powers the reactive UI components
- **Ecto**: Database operations with PostgreSQL
- **Tailwind CSS + Alpine.js**: Required for SelectoComponents styling and interactivity

### Core Architecture

**Domain Layer (`lib/selecto_test/`):**
- `PagilaDomain` & `PagilaDomainFilms`: Define data domains for Selecto configuration
- `Store/`: Ecto schemas representing Pagila database tables (Film, Actor, etc.)
- `SavedView`: Manages persistent view configurations with context-based organization

**Web Layer (`lib/selecto_test_web/live/`):**
- `PagilaLive`: Main LiveView handling multiple routes (:index for actors, :films for films)
- Uses SelectoComponents.Form for dynamic data visualization
- Supports multiple view types: Aggregate (with drill-down), Detail, and Graph views

**Data Flow:**
1. LiveView configures Selecto with domain and repository
2. SelectoComponents provide interactive data views (aggregate, detail, graph)
3. SavedView system persists user configurations by context path
4. Views support drill-down navigation between aggregate and detail modes

### Database Schema
- Uses Pagila sample database (film rental store)
- Custom additions: `saved_views`, `tags`, `flags` tables
- Main entities: Film, Actor, Category, Customer, Rental, Inventory

### Asset Pipeline
- Tailwind CSS with custom config (`assets/tailwind.config.js`)
- JavaScript hooks for SelectoComponents integration (`assets/js/hooks/`)
- Must include Alpine.js and push event hooks for SelectoComponents to function

### Routes
- `/` and `/pagila`: Actor domain interface
- `/pagila_films`: Film domain interface
- LiveView actions determine which domain configuration to load