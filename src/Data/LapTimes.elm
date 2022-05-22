module Data.LapTimes exposing (Car, Driver, Lap, LapTimes, lapTimesDecoder)

import Data.Duration exposing (Duration, durationDecoder)
import Json.Decode as Decode exposing (Decoder, field, int, string)



-- TYPE


type alias LapTimes =
    List Car


type alias Car =
    { carNumber : String
    , driver : Driver
    , laps : List Lap
    }


type alias Driver =
    { name : String }


type alias Lap =
    { lap : Int
    , time : Duration
    , best : Duration
    , elapsed : Duration
    }



-- DECODER


lapTimesDecoder : Decoder LapTimes
lapTimesDecoder =
    Decode.list carDecoder


carDecoder : Decoder Car
carDecoder =
    Decode.map3 Car
        (field "carNumber" string)
        (field "driver" driverDecoder)
        (field "laps" lapsDecoder)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver
        (field "name" string)


lapsDecoder : Decoder (List Lap)
lapsDecoder =
    Decode.map toLaps
        (Decode.list lapDecoder)


toLaps : List { lap : Int, time : Duration } -> List Lap
toLaps laps =
    List.indexedMap
        (\count { lap, time } ->
            { lap = lap
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
