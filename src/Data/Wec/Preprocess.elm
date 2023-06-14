module Data.Wec.Preprocess exposing (..)

import AssocList
import AssocList.Extra
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
        driverName_ =
            List.head laps
                |> Maybe.map .driverName
                |> Maybe.withDefault ""
    in
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
        |> (\laps_ ->
                { carNumber = carNumber
                , driverName = driverName_
                , laps = laps_
                }
           )
