module Data.F1.Decoder exposing (Car, Data, Driver, Lap, decoder)

import Json.Decode as Decode exposing (Decoder, field, int, string)
import Motorsport.Duration exposing (Duration, durationDecoder)



-- TYPE


type alias Data =
    List Car


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


decoder : Decoder Data
decoder =
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
    Decode.map2 Lap
        (field "lap" int)
        (field "time" durationDecoder)
