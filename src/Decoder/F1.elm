module Decoder.F1 exposing (Car, Driver, Lap, carDecoder, carsDecoder)

import Data.Duration exposing (Duration, durationDecoder)
import Json.Decode as Decode exposing (Decoder, field, int, string)



-- TYPE


type alias Car =
    { carNumber : String
    , driver : Driver
    , laps : List Lap
    }


type alias Driver =
    { name : String }


type alias Lap =
    { lap : Int, time : Duration }



-- DECODER


carsDecoder : Decoder (List Car)
carsDecoder =
    Decode.list carDecoder


carDecoder : Decoder Car
carDecoder =
    Decode.map3 Car
        (field "carNumber" string)
        (field "driver" driverDecoder)
        (field "laps" <| Decode.list lapDecoder)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver
        (field "name" string)


lapDecoder : Decoder Lap
lapDecoder =
    Decode.map2 (\lap time -> { lap = lap, time = time })
        (field "lap" int)
        (field "time" durationDecoder)
