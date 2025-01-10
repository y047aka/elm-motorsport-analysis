module Motorsport.Car exposing (Car, carDecoder)

import Json.Decode as Decode exposing (Decoder, bool, field, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (required)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)


type alias Car =
    { carNumber : String
    , drivers : List Driver
    , class : Class
    , group : String
    , team : String
    , manufacturer : String
    , startPosition : Int
    , laps : List Lap
    , currentLap : Maybe Lap
    , lastLap : Maybe Lap
    }



-- DECODER


carDecoder : Decoder Car
carDecoder =
    Decode.succeed Car
        |> required "carNumber" string
        |> required "drivers" (Decode.list driverDecoder)
        |> required "class" classDecoder
        |> required "group" string
        |> required "team" string
        |> required "manufacturer" string
        |> required "startPosition" int
        |> required "laps" (Decode.list lapDecoder)
        |> required "currentLap" (Decode.maybe lapDecoder)
        |> required "lastLap" (Decode.maybe lapDecoder)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map2 Driver
        (field "name" string)
        (field "isCurrentDriver" bool)


classDecoder : Decoder Class
classDecoder =
    string |> Decode.andThen (Class.fromString >> Json.Decode.Extra.fromMaybe "Expected a Class")


lapDecoder : Decoder Lap
lapDecoder =
    Decode.succeed Lap
        |> required "carNumber" string
        |> required "driver" string
        |> required "lap" int
        |> required "position" (Decode.maybe int)
        |> required "time" durationDecoder
        |> required "best" durationDecoder
        |> required "sector_1" durationDecoder
        |> required "sector_2" durationDecoder
        |> required "sector_3" durationDecoder
        |> required "s1_best" durationDecoder
        |> required "s2_best" durationDecoder
        |> required "s3_best" durationDecoder
        |> required "elapsed" durationDecoder


durationDecoder : Decoder Duration
durationDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a Duration")
