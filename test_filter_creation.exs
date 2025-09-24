#!/usr/bin/env elixir

# When we have coldef with group_by_filter = "actor_id"
# And we create: %{"phx-value-actor_id" => "71"}
# The HTML becomes: <div ... phx-value-actor_id="71">
# Phoenix should give us params: %{"actor_id" => "71"}

# But the user sees: %{"filter" => "full_name", "value" => "71"}

# This can only happen if:
# 1. The filter map is created as: %{"phx-value-filter" => "full_name", "phx-value-value" => "71"}
# 2. Or there's a transformation somewhere

# Let me check if maybe the field identifier is being used somewhere

IO.puts("The issue is that the filter map is being created with the wrong structure!")
IO.puts("We need to find where 'phx-value-filter' and 'phx-value-value' are being set")
