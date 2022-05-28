module Data.Decoder exposing (Decoded, decoder)

import Data.Duration exposing (Duration, durationDecoder)
import Data.Lap exposing (Lap)
import Json.Decode as Decode exposing (Decoder, field, int, string)



-- TYPE


type alias Decoded =
    List (List Lap)


type alias InternalDriver =
    { name : String }


type alias InternalLap =
    { lap : Int, time : Duration }



-- DECODER


decoder : Decoder Decoded
decoder =
    Decode.list decoderByCar


decoderByCar : Decoder (List Lap)
decoderByCar =
    Decode.map3 toLaps
        (field "carNumber" string)
        (field "driver" driverDecoder)
        (field "laps" <| Decode.list lapDecoder)


driverDecoder : Decoder InternalDriver
driverDecoder =
    Decode.map InternalDriver
        (field "name" string)


toLaps : String -> InternalDriver -> List InternalLap -> List Lap
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


lapDecoder : Decoder InternalLap
lapDecoder =
    Decode.map2 (\lap time -> { lap = lap, time = time })
        (field "lap" int)
        (field "time" durationDecoder)
