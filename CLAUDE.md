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

# Run specific test files with timeout
timeout 30 mix test test/specific_test.exs --max-cases 1
```

## Architecture Overview

This is a Phoenix LiveView application that serves as a test/development environment for the Selecto ecosystem. The app provides dynamic data visualization interfaces for the Pagila sample database.

**Important:** This project encompasses the `selecto_test` application and the related projects in the `vendor/` directory:
- `selecto` (v0.2.6) - Core query builder library with advanced SQL generation, joins, CTEs, and OLAP functions
- `selecto_components` (v0.2.8) - Phoenix LiveView components for interactive data visualization
- `selecto_dome` (v0.1.0) - Data manipulation interface for Selecto query results
- `selecto_mix` (v0.1.0) - Mix tasks and generators for Selecto domain configuration
- `selecto_kino` - Livebook integration for interactive querying

When making changes, you may need to modify code across multiple projects to maintain compatibility.

### Key Dependencies
- **Selecto** (v0.2.6): Advanced query builder with comprehensive join support, CTEs, hierarchical queries, and OLAP functions
- **SelectoComponents** (v0.2.8): LiveView components for aggregate, detail, and graph views with drill-down navigation
- **SelectoDome** (v0.1.0): Data manipulation and change tracking interface
- **SelectoMix**: Code generation tools for domains and schemas
- **Phoenix LiveView**: Powers the reactive UI components (v1.1+)
- **Ecto**: Database operations with PostgreSQL (v3.12+)
- **Tailwind CSS + Alpine.js**: Required for SelectoComponents styling and interactivity
- **Timex**: Date/time handling across all Selecto components
- **UUID**: Identifier generation for saved views and components

### Core Architecture

**Domain Layer (`lib/selecto_test/`):**
- `PagilaDomain` & `PagilaDomainFilms`: Rich domain configurations with custom columns, filters, and join relationships
- `Store/`: Comprehensive Ecto schemas for Pagila database tables (Film, Actor, Category, Customer, etc.)
- `Blog/`: Additional domain schemas for testing (Author, Post, Category, Comment, BlogTag)
- `Test/`: Solar system test domain (SolarSystem, Planet, Satellite)
- `SavedView` & `SavedViewContext`: Persistent view configurations with context-based organization
- `Seed`: Database seeding utilities

**Web Layer (`lib/selecto_test_web/`):**
- `PagilaLive`: Main LiveView with multi-domain routing (:index for actors, :films for films, :stores)
- `PagilaFilmLive`: Dedicated film detail view
- Uses `SelectoComponents.Form` for dynamic data visualization and interaction
- Supports multiple view types: Aggregate (with drill-down), Detail, and Graph views
- Custom components in `components/` for layouts and core UI elements

**Data Flow:**
1. LiveView configures Selecto with domain-specific schemas and Postgrex connection
2. SelectoComponents provide interactive data views with real-time filtering and aggregation
3. SavedView system persists user configurations by URL context path
4. Views support drill-down navigation between aggregate and detail modes
5. Custom filters and columns enable advanced data exploration

### Database Schema
- **Pagila Database**: Film rental store with Actor, Film, Category, Customer, Rental, Inventory, Staff, Store entities
- **Custom Extensions**: `saved_views`, `tags`, `flags`, and `film_tag`/`film_flag` junction tables
- **Blog Domain**: Author, Post, Category, Comment relationships for testing complex domains
- **Test Domains**: Solar system hierarchy (SolarSystem → Planet → Satellite)
- **Migration Strategy**: Schema loaded externally, with custom tables added via migrations

### Asset Pipeline
- **Tailwind CSS**: Custom configuration including SelectoComponents content paths
- **JavaScript Integration**: 
  - Push event hooks for SelectoComponents interactivity
  - Color scheme management (`assets/js/hooks/color-scheme-hook.js`)
  - Alpine.js integration required for SelectoComponents functionality
- **Build Process**: esbuild + Tailwind with development and production targets

### Routes & Navigation
- `/` and `/pagila`: Actor domain interface with film relationships
- `/pagila_films`: Film-centric domain with ratings and categorization
- `/pagila_stores`: Store management interface (planned)
- `/pagila/film/:film_id`: Individual film detail pages
- **Development Routes**: LiveDashboard at `/dev/dashboard`, Swoosh mailbox preview

### Testing Infrastructure
- **Comprehensive Test Suite**: 30+ test files covering core functionality, integrations, and edge cases
- **Selecto Core Tests**: Query building, filtering, joins, CTEs, and OLAP functions
- **Dome Integration**: Database operations and change tracking
- **Test Support**: Custom test cases, helpers, and database connection utilities
- **Performance Testing**: Benchmarking and memory profiling capabilities

### Development Features
- **Livebook Integration**: `notebooks/` directory with comprehensive demos and tutorials
- **Code Generation**: Mix tasks for domain and schema generation via SelectoMix
- **Documentation**: Extensive guides for joins, OLAP patterns, and advanced usage
- **Multi-Environment**: Development, test, and production configurations with Docker support