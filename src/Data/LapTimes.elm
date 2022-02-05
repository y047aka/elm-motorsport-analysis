module Data.LapTimes exposing (Car, Driver, Lap, LapTimes, lapTimesDecoder)

import Data.LapTime exposing (LapTime, lapTimeDecoder)
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
    , time : LapTime
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
        (field "laps" (Decode.list lapDecoder))


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver
        (field "name" string)


lapDecoder : Decoder Lap
lapDecoder =
    Decode.map2 Lap
        (field "lap" int)
        (field "time" lapTimeDecoder)
