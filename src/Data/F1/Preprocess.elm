module Data.F1.Preprocess exposing (preprocess)

import Data.F1.Decoder as F1
import Data.Wec.Class
import List.Extra as List
import Motorsport.Car exposing (Car)


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
    in
    List.map (preprocess_ startPositions) cars


preprocess_ : List String -> F1.Car -> Car
preprocess_ startPositions { carNumber, driver, laps } =
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
                        , time = time
                        , best =
                            laps
                                |> List.take (count + 1)
                                |> List.map .time
                                |> List.minimum
                                |> Maybe.withDefault 0
                        , elapsed =
                            laps
                                |> List.take (count + 1)
                                |> List.foldl (.time >> (+)) 0
                        }
                    )
    in
    { carNumber = carNumber
    , driverName = driver.name
    , class = Data.Wec.Class.none
    , group = "TODO"
    , team = "TODO"
    , manufacturer = "TODO"
    , startPosition = startPosition
    , laps = laps_
    }
