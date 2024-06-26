module Data.F1.Preprocess exposing (preprocess)

import Data.F1.Decoder as F1
import Data.Wec.Class
import Motorsport.Car exposing (Car)


preprocess : F1.Data -> List Car
preprocess =
    List.map preprocess_


preprocess_ : F1.Car -> Car
preprocess_ { carNumber, driver, laps } =
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
        |> (\laps_ ->
                { carNumber = carNumber
                , driverName = driver.name
                , class = Data.Wec.Class.none
                , group = "TODO"
                , team = "TODO"
                , manufacturer = "TODO"
                , laps = laps_
                }
           )
