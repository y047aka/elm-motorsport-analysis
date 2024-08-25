module Data.Wec.Preprocess exposing (..)

import AssocList
import AssocList.Extra
import Data.Wec.Class
import Data.Wec.Decoder as Wec
import List.Extra as List
import Motorsport.Car exposing (Car)


preprocess : List Wec.Lap -> List Car
preprocess laps =
    let
        startPositions =
            List.filter (\{ lapNumber } -> lapNumber == 1) laps
                |> List.sortBy .elapsed
                |> List.map .carNumber
    in
    laps
        |> AssocList.Extra.groupBy .carNumber
        |> AssocList.toList
        |> List.map (preprocess_ startPositions)


preprocess_ : List String -> ( String, List Wec.Lap ) -> Car
preprocess_ startPositions ( carNumber, laps ) =
    let
        { driverName_, class_, group_, team_, manufacturer_ } =
            List.head laps
                |> Maybe.map
                    (\{ driverName, class, group, team, manufacturer } ->
                        { driverName_ = driverName
                        , class_ = class
                        , group_ = group
                        , team_ = team
                        , manufacturer_ = manufacturer
                        }
                    )
                |> Maybe.withDefault
                    { class_ = Data.Wec.Class.none
                    , team_ = ""
                    , group_ = ""
                    , driverName_ = ""
                    , manufacturer_ = ""
                    }

        startPosition =
            startPositions
                |> List.findIndex ((==) carNumber)
                |> Maybe.withDefault 0

        laps_ =
            laps
                |> List.indexedMap
                    (\index { driverName, lapNumber, lapTime, elapsed } ->
                        { carNumber = carNumber
                        , driver = driverName
                        , lap = lapNumber
                        , time = lapTime
                        , best =
                            laps
                                |> List.take (index + 1)
                                |> List.map .lapTime
                                |> List.minimum
                                |> Maybe.withDefault 0
                        , elapsed = elapsed
                        }
                    )
    in
    { carNumber = carNumber
    , driverName = driverName_
    , class = class_
    , group = group_
    , team = team_
    , manufacturer = manufacturer_
    , startPosition = startPosition
    , laps = laps_
    }
