module Data.F1.Preprocess exposing (preprocess)

import AssocList
import AssocList.Extra
import Data.F1.Decoder as F1
import List.Extra as List
import Motorsport.Car exposing (Car)
import Motorsport.Class as Class
import Motorsport.Lap as Lap


preprocess : F1.Data -> List Car
preprocess cars =
    let
        startPositions =
            cars
                |> List.map
                    (\{ carNumber, laps } ->
                        List.filter (\{ lap } -> lap == 1) laps
                            |> List.map (\{ time } -> { carNumber = carNumber, time = time })
                    )
                |> List.concat
                |> List.sortBy .time
                |> List.map .carNumber

        ordersByLap =
            cars
                |> List.map
                    (\{ carNumber, laps } ->
                        List.map
                            (\{ lap, time } ->
                                { carNumber = carNumber
                                , lapNumber = lap
                                , time = time
                                , elapsed =
                                    laps
                                        |> List.take (lap + 1)
                                        |> List.foldl (.time >> (+)) 0
                                }
                            )
                            laps
                    )
                |> List.concat
                |> AssocList.Extra.groupBy .lapNumber
                |> AssocList.toList
                |> List.map
                    (\( lapNumber, cars_ ) ->
                        { lapNumber = lapNumber
                        , order = cars_ |> List.sortBy .elapsed |> List.map .carNumber
                        }
                    )
    in
    List.map
        (\{ carNumber, driver, laps } ->
            preprocess_
                { carNumber = carNumber
                , driver = driver
                , laps = laps
                , startPositions = startPositions
                , ordersByLap = ordersByLap
                }
        )
        cars


type alias OrdersByLap =
    List { lapNumber : Int, order : List String }


getPositionAt : { carNumber : String, lapNumber : Int } -> OrdersByLap -> Maybe Int
getPositionAt { carNumber, lapNumber } ordersByLap =
    ordersByLap
        |> List.find (.lapNumber >> (==) lapNumber)
        |> Maybe.andThen (.order >> List.findIndex ((==) carNumber))


preprocess_ :
    { carNumber : String
    , driver : F1.Driver
    , laps : List F1.Lap
    , startPositions : List String
    , ordersByLap : OrdersByLap
    }
    -> Car
preprocess_ { carNumber, driver, laps, startPositions, ordersByLap } =
    let
        startPosition =
            startPositions
                |> List.findIndex ((==) carNumber)
                |> Maybe.withDefault 0

        laps_ =
            laps
                |> List.indexedMap
                    (\count { lap, time } ->
                        { carNumber = carNumber
                        , driver = driver.name
                        , lap = lap
                        , position =
                            getPositionAt { carNumber = carNumber, lapNumber = lap } ordersByLap
                        , time = time
                        , best =
                            laps
                                |> List.take (count + 1)
                                |> Lap.personalBestLap
                                |> Maybe.map .time
                                |> Maybe.withDefault 0
                        , elapsed =
                            laps
                                |> List.take (count + 1)
                                |> List.foldl (.time >> (+)) 0
                        }
                    )
    in
    { carNumber = carNumber
    , drivers = [ { name = driver.name, isCurrentDriver = True } ]
    , class = Class.none
    , group = "TODO"
    , team = driverToTeamName_2022 driver.name
    , manufacturer = "TODO"
    , startPosition = startPosition
    , laps = laps_
    }


driverToTeamName_2022 : String -> String
driverToTeamName_2022 driver =
    case driver of
        "Max Verstappen" ->
            "Red Bull Racing"

        "Sergio Pérez" ->
            "Red Bull Racing"

        "Lewis Hamilton" ->
            "Mercedes"

        "George Russell" ->
            "Mercedes"

        "Charles Leclerc" ->
            "Ferrari"

        "Carlos Sainz" ->
            "Ferrari"

        "Lando Norris" ->
            "McLaren"

        "Daniel Ricciardo" ->
            "McLaren"

        "Sebastian Vettel" ->
            "Aston Martin"

        "Lance Stroll" ->
            "Aston Martin"

        "Fernando Alonso" ->
            "Alpine"

        "Esteban Ocon" ->
            "Alpine"

        "Pierre Gasly" ->
            "AlphaTauri"

        "Yuki Tsunoda" ->
            "AlphaTauri"

        "Valtteri Bottas" ->
            "Alfa Romeo"

        "Zhou Guanyu" ->
            "Alfa Romeo"

        "Kevin Magnussen" ->
            "Haas"

        "Mick Schumacher" ->
            "Haas"

        "Alexander Albon" ->
            "Williams"

        "Nicholas Latifi" ->
            "Williams"

        _ ->
            "Unknown"
