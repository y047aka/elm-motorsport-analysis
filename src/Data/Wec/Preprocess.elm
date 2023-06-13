module Data.Wec.Preprocess exposing (..)

import AssocList
import AssocList.Extra
import Data.Wec.Decoder as Wec
import Motorsport.Lap exposing (Lap)


preprocess : List Wec.Lap -> List (List Lap)
preprocess =
    AssocList.Extra.groupBy .carNumber
        >> AssocList.toList
        >> List.map preprocess_


preprocess_ : ( Int, List Wec.Lap ) -> List Lap
preprocess_ ( carNumber, laps ) =
    List.indexedMap
        (\index { driverName, lapNumber, lapTime, elapsed } ->
            { carNumber = String.fromInt carNumber
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
        laps
