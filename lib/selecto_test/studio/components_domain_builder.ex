defmodule SelectoTest.Studio.ComponentsDomainBuilder do
  @moduledoc false

  defdelegate build_selecto(payload), to: SelectoStudio.Studio.ComponentsDomainBuilder
end
