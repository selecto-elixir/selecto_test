defmodule SelectoTestWeb.PageControllerTest do
  use SelectoTestWeb.ConnCase


  setup_all do
    domain = SelectoTest.PagilaDomainFilms.domain()
    # Use SelectoTest.Repo for consistency with production
    selecto = Selecto.configure(domain, SelectoTest.Repo)
    {:ok, domain: domain, selecto: selecto}
  end



end
