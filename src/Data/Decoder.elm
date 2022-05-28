module Data.Decoder exposing (Decoded, decoder)

import Data.Duration exposing (Duration, durationDecoder)
import Data.Lap exposing (Lap)
import Json.Decode as Decode exposing (Decoder, field, int, string)



-- TYPE


type alias Decoded =
    List (List Lap)


type alias Driver =
    { name : String }



-- DECODER


decoder : Decoder Decoded
decoder =
    Decode.list carDecoder


carDecoder : Decoder (List Lap)
carDecoder =
    Decode.map3 toLaps
        (field "carNumber" string)
        (field "driver" driverDecoder)
        (field "laps" lapsDecoder)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver
        (field "name" string)


lapsDecoder : Decoder (List { lap : Int, time : Duration })
lapsDecoder =
    Decode.list lapDecoder


toLaps : String -> Driver -> List { lap : Int, time : Duration } -> List Lap
toLaps carNumber driver laps =
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


lapDecoder : Decoder { lap : Int, time : Duration }
lapDecoder =
    Decode.map2 (\lap time -> { lap = lap, time = time })
        (field "lap" int)
        (field "time" durationDecoder)
