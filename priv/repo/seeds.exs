# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ListableTest.Repo.insert!(%ListableTest.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

## Aside from our solar system this is all made up.

ListableTest.Repo.insert( %ListableTest.Test.SolarSystem{
  galaxy: "Milky Way",
  name: "Sol"
 } )
ListableTest.Repo.insert( %ListableTest.Test.SolarSystem{
  galaxy: "Milky Way",
  name: "Alpha Centauri"
 } )
ListableTest.Repo.insert( %ListableTest.Test.SolarSystem{
  galaxy: "Andromeda",
  name: "Rats"
 } )
 ListableTest.Repo.insert( %ListableTest.Test.SolarSystem{
   galaxy: "Milky Way",
   name: "Beta Centauri"
  } )

  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Mercury",
    mass: 0.330,
    radius: 4879/2,
    surface_temp: 167.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Venus",
    mass: 4.87,
    radius: 12104/2,
    surface_temp: 464.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Earth",
    mass: 5.97,
    radius: 12756/2,
    surface_temp: 15.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Mars",
    mass: 0.642,
    radius: 6792/2,
    surface_temp: -65.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Jupiter",
    mass: 1898.0,
    radius: 142984/2,
    surface_temp: -110.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Saturn",
    mass: 120536.0,
    radius: 4879/2,
    surface_temp: -140.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Uranus",
    mass: 86.8,
    radius: 51118/2,
    surface_temp: -195.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Neptune",
    mass: 102.0,
    radius: 49528/2,
    surface_temp: -200.0
  })
  ListableTest.Repo.insert( %ListableTest.Test.Planet{
    solar_system_id: 1,
    name: "Pluto",
    mass: 0.0130,
    radius: 2376/2,
    surface_temp: -225.0
  })
