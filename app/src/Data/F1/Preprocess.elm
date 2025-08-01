module Data.F1.Preprocess exposing (preprocess)

import AssocList
import AssocList.Extra
import Data.F1.Decoder as F1
import List.Extra as List
import Motorsport.Car exposing (Car, Status(..))
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Lap.Performance exposing (findPersonalBest)
import Motorsport.Manufacturer as Manufacturer


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
    , driver : Driver
    , laps : List F1.Lap
    , startPositions : List String
    , ordersByLap : OrdersByLap
    }
    -> Car
preprocess_ { carNumber, driver, laps, startPositions, ordersByLap } =
    let
        metadata =
            { carNumber = carNumber
            , drivers = [ driver ]
            , class = Class.none
            , group = "TODO"
            , team = driverToTeamName_2022 driver.name
            , manufacturer = teamNameToManufacturer (driverToTeamName_2022 driver.name)
            }

        startPosition =
            startPositions
                |> List.findIndex ((==) carNumber)
                |> Maybe.withDefault 0

        laps_ =
            laps
                |> List.indexedMap
                    (\count { lap, time } ->
                        { carNumber = carNumber
                        , driver = driver
                        , lap = lap
                        , position =
                            getPositionAt { carNumber = carNumber, lapNumber = lap } ordersByLap
                        , time = time
                        , best =
                            laps
                                |> List.take (count + 1)
                                |> findPersonalBest
                                |> Maybe.map .time
                                |> Maybe.withDefault 0
                        , sector_1 = 0
                        , sector_2 = 0
                        , sector_3 = 0
                        , s1_best = 0
                        , s2_best = 0
                        , s3_best = 0
                        , elapsed =
                            laps
                                |> List.take (count + 1)
                                |> List.foldl (.time >> (+)) 0
                        , miniSectors = Nothing
                        }
                    )
    in
    { metadata = metadata
    , startPosition = startPosition
    , laps = laps_
    , currentLap = Nothing
    , lastLap = Nothing
    , status = PreRace
    , currentDriver = Just driver
    }


teamNameToManufacturer : String -> Manufacturer.Manufacturer
teamNameToManufacturer teamName =
    case teamName of
        "Red Bull Racing" ->
            Manufacturer.Other

        -- Red Bull is an energy drink company, not a car manufacturer
        "Mercedes" ->
            Manufacturer.Mercedes

        "Ferrari" ->
            Manufacturer.Ferrari

        "McLaren" ->
            Manufacturer.McLaren

        "Aston Martin" ->
            Manufacturer.AstonMartin

        "Alpine" ->
            Manufacturer.Alpine

        "AlphaTauri" ->
            Manufacturer.Other

        -- AlphaTauri is Red Bull subsidiary
        "Alfa Romeo" ->
            Manufacturer.Other

        -- Alfa Romeo not in our WEC list
        "Haas" ->
            Manufacturer.Other

        -- Haas is not a car manufacturer
        "Williams" ->
            Manufacturer.Other

        -- Williams is not a car manufacturer
        _ ->
            Manufacturer.Other


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
