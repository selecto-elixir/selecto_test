defmodule SelectoTestWeb.PageControllerTest do
  use SelectoTestWeb.ConnCase


  setup_all do
    domain = SelectoTest.PagilaDomainFilms.domain()
    selecto = Selecto.configure(domain, SelectoTest.Repo)
    {:ok, domain: domain, selecto: selecto}
  end



end
