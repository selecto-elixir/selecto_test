defmodule ListableTest.Seed do

  def init() do

    ListableTest.Repo.insert(%ListableTest.Test.SolarSystem{
      galaxy: "Milky Way",
      name: "Sol"
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Mercury",
      mass: 3.3e23,
      radius: 4879 / 2,
      surface_temp: 167.0
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Venus",
      mass: 4.87e24,
      radius: 12104 / 2,
      surface_temp: 464.0,
      atmosphere: true
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Earth",
      mass: 5.97e24,
      radius: 12756 / 2,
      surface_temp: 15.0,
      atmosphere: true
    })

    ListableTest.Repo.insert(%ListableTest.Test.Satellite{
      planet_id: 3,
      name: "Moon",
      mass: 7.3e22,
      radius: 12756 / 2
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Mars",
      mass: 6.4e23,
      radius: 6792 / 2,
      surface_temp: -65.0,
      atmosphere: true
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Jupiter",
      mass: 1.9e27,
      radius: 142_984 / 2,
      surface_temp: -110.0,
      atmosphere: true
    })

    ListableTest.Repo.insert(%ListableTest.Test.Satellite{
      planet_id: 5,
      name: "IO",
      mass: 8.93e22,
      radius: 12756 / 2
    })

    ListableTest.Repo.insert(%ListableTest.Test.Satellite{
      planet_id: 5,
      name: "Europa",
      mass: 4.8e22,
      radius: 12756 / 2
    })

    ListableTest.Repo.insert(%ListableTest.Test.Satellite{
      planet_id: 5,
      name: "Ganymede",
      mass: 1.48e23,
      radius: 12756 / 2
    })

    ListableTest.Repo.insert(%ListableTest.Test.Satellite{
      planet_id: 5,
      name: "Callisto",
      mass: 1.08e23,
      radius: 12756 / 2
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Saturn",
      mass: 5.685e26,
      radius: 120_536.0 / 2,
      surface_temp: -140.0,
      atmosphere: true
    })

    ListableTest.Repo.insert(%ListableTest.Test.Satellite{
      planet_id: 6,
      name: "Titan",
      mass: 1.35e23,
      radius: 12756 / 2
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Uranus",
      mass: 8.682e25,
      radius: 51118 / 2,
      surface_temp: -195.0,
      atmosphere: true
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Neptune",
      mass: 1.02e26,
      radius: 49528 / 2,
      surface_temp: -200.0,
      atmosphere: true
    })

    ListableTest.Repo.insert(%ListableTest.Test.Planet{
      solar_system_id: 1,
      name: "Pluto",
      mass: 1.30e22,
      radius: 2376 / 2,
      surface_temp: -225.0,
      atmosphere: true
    })

    for n <- ~w(Sirius Betelgeuse Deneb PCentauri Ross Wolf Groombridge) do
      {:ok, sol} = ListableTest.Repo.insert(%ListableTest.Test.SolarSystem{
        galaxy: "Milky Way",
        name: n
      })

      for p <- Enum.to_list( 1..3 ) do
        ListableTest.Repo.insert(%ListableTest.Test.Planet{
          solar_system_id: sol.id,
          name: "Planet #{p}",
          mass: 1.30e22 * :rand.uniform(10_000_000),
          radius: 2376 / 2 * :rand.uniform(1_000),
          surface_temp: 1000 -1.0 * :rand.uniform(1_270),
          atmosphere: true
        })
      end



    end



  end



end
