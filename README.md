# selecto Test Project

This project is a test/development project for Selecto and SelectoComponents modules. 

This project uses git checkouts to [selecto](https://github.com/selecto-elixir/selecto) and [selecto_components](https://github.com/selecto-elixir/selecto_components) which it expects to find in the vendor subdir.

This app provides live views:

- / and /pagila component interface targeted to [pagila database](https://github.com/devrimgunduz/pagila)
- /pagila_films same DB, films table

There is also the beginnings of a livebook in the notebooks dir.

Notes
Projects using selecto_components should include Tailwind and Alpine.js as is done in this project. You also need to add the push event hook from assets/js/hooks.

To use:

1) checkout selecto and selecto_components into vendor subdir
2) mix deps.get
3) mix ecto.create
4) mix ecto.migrate
5) mix run priv/repo/seeds.exs
6) To use Pagila databse, add the tables and data from the git repo to your dev db
7) iex --sname selecto --cookie COOKIE -S mix phx.server

(the sname / cookie are only required for connection via the livebook)

