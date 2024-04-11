defmodule SelectoTest.Seed do
  def init() do

SelectoTest.Repo.insert! %SelectoTest.Store.Flag{name: "F1"}
SelectoTest.Repo.insert! %SelectoTest.Store.Flag{name: "F2"}
SelectoTest.Repo.insert! %SelectoTest.Store.Flag{name: "F3"}
SelectoTest.Repo.insert! %SelectoTest.Store.Flag{name: "F4"}




  end
end
