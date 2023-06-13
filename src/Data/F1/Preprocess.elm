module Data.F1.Preprocess exposing (preprocess)

import Data.F1.Decoder as F1
import Motorsport.Lap exposing (Lap)


preprocess : List F1.Car -> List (List Lap)
preprocess =
    List.map preprocess_


preprocess_ : F1.Car -> List Lap
preprocess_ { carNumber, driver, laps } =
    List.indexedMap
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
        laps
