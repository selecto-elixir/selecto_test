#!/usr/bin/env elixir

# Test what Phoenix does with phx-value-* attributes
# When you have: <div phx-click="test" phx-value-actor_id="71">
# Phoenix gives you: %{"actor_id" => "71"}

# So if our filter map contains: %{"phx-value-actor_id" => "71"}
# And we spread it with { filters }
# The HTML becomes: <div ... phx-value-actor_id="71">
# And Phoenix gives us: %{"actor_id" => "71"}

IO.puts("When HTML has: phx-value-actor_id=\"71\"")
IO.puts("Phoenix params will be: %{\"actor_id\" => \"71\"}")
IO.puts("")
IO.puts("So if we're getting %{\"filter\" => \"full_name\", \"value\" => \"71\"}")
IO.puts("Then the HTML must have: phx-value-filter=\"full_name\" phx-value-value=\"71\"")
IO.puts("")
IO.puts("This means our filter map is being created with the wrong keys!")
