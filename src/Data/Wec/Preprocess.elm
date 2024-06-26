module Data.Wec.Preprocess exposing (..)

import AssocList
import AssocList.Extra
import Data.Wec.Class
import Data.Wec.Decoder as Wec
import Motorsport.Car exposing (Car)


preprocess : List Wec.Lap -> List Car
preprocess =
    AssocList.Extra.groupBy .carNumber
        >> AssocList.toList
        >> List.map preprocess_


preprocess_ : ( String, List Wec.Lap ) -> Car
preprocess_ ( carNumber, laps ) =
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
    , laps = laps_
    }
