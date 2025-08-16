# Project Overview

This is an Elixir/Phoenix project that serves as a test and development environment for the `selecto` and `selecto_components` Elixir libraries. The project demonstrates how to integrate these components into a Phoenix application, providing live views for interacting with a Pagila sample database.

**Key Technologies:**

*   **Elixir:** The core programming language.
*   **Phoenix Framework:** The web framework used for the application.
*   **LiveView:** For building real-time, interactive user interfaces.
*   **Ecto:** The database wrapper and query language.
*   **PostgreSQL:** The database used for the Pagila sample data.
*   **Selecto:** A library for creating data-driven components.
*   **SelectoComponents:** A set of pre-built components for use with Selecto.
*   **Tailwind CSS:** For styling the user interface.
*   **Alpine.js:** For client-side interactivity.

**Architecture:**

The project is structured as a standard Phoenix application. The main components are:

*   **`lib/selecto_test`:** The core application logic.
*   **`lib/selecto_test_web`:** The web interface, including controllers, views, and templates.
*   **`lib/selecto_test_web/live`:** The LiveView modules that power the interactive features.
*   **`priv/repo`:** The database migrations and seeds.
*   **`assets`:** The frontend assets, including CSS and JavaScript.
*   **`vendor`:** Contains local checkouts of the `selecto`, `selecto_components`, and `selecto_kino` libraries. These are co-developed with this test project and are considered in scope.

# Building and Running

**Prerequisites:**

*   Elixir
*   Erlang
*   PostgreSQL

**Setup and Execution:**

1.  **Clone `selecto` and `selecto_components`:**
    ```bash
    git clone https://github.com/selecto-elixir/selecto.git vendor/selecto
    git clone https://github.com/selecto-elixir/selecto_components.git vendor/selecto_components
    ```

2.  **Install dependencies:**
    ```bash
    mix deps.get
    ```

3.  **Set up the database:**
    ```bash
    mix ecto.setup
    ```
    This command will create the database, run migrations, and seed the database with initial data.

4.  **Load the Pagila database schema and data:**
    This project is designed to work with the Pagila sample database. You will need to load the schema and data into your development database. You can find the Pagila database dump at https://github.com/devrimgunduz/pagila.

5.  **Start the Phoenix server:**
    ```bash
    iex -S mix phx.server
    ```

The application will be available at `http://localhost:4080`.

**Available Routes:**

*   `/`: The main page, which displays the actors from the Pagila database.
*   `/pagila`: Same as the main page.
*   `/pagila_films`: Displays the films from the Pagila database.

# Development Conventions

*   **Testing:** Tests are located in the `test` directory. You can run the test suite with the following command:
    ```bash
    mix test
    ```

*   **Styling:** The project uses Tailwind CSS for styling. The configuration is in `assets/tailwind.config.js`.

*   **JavaScript:** The project uses Alpine.js for client-side interactivity. The main JavaScript file is `assets/js/app.js`.
