# selecto Test Project

This project uses git checkouts to [selecto](https://github.com/seeken/selecto) and [selecto_components](https://github.com/seeken/selecto_components) which it expects to find in the vendor subdir.

This app provides 3 live views:

- / the component interface to edit / run queries
- /aggregates a test view only of aggregates
- /detail a test detail view

There is also the beginnings of a livebook in the notebooks dir.

Notes
Projects using selecto_components should include Tailwind and Alpine.js as is done in this project. You also need to add the push event hook from assets/js/hooks.

Plans:

- bigger database with lots of tables and real data

To use:

1) checkout selecto and selecto_components into vendor subdir
2) mix deps.get
3) mix ecto.create
4) mix ecto.migrate
5) mix run priv/repo/seeds.exs
6) iex --sname selecto --cookie COOKIE -S mix phx.server

(the sname / cookie are only required for connection via the livebook)

