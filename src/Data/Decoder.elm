module Data.Decoder exposing (Decoded, decoder)

import Data.Lap exposing (Lap)
import Decoder.F1 as F1
import Json.Decode as Decode exposing (Decoder)



-- TYPE


type alias Decoded =
    List (List Lap)



-- DECODER


decoder : Decoder Decoded
decoder =
    Decode.map (List.map toLaps) F1.carsDecoder


toLaps : F1.Car -> List Lap
toLaps { carNumber, driver, laps } =
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
