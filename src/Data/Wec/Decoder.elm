module Data.Wec.Decoder exposing (Lap, lapDecoder)

import Json.Decode as Decode exposing (Decoder, float, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (required)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Duration as Duration exposing (Duration)



-- MODEL


type alias Lap =
    { carNumber : String
    , driverNumber : Int
    , lapNumber : Int
    , lapTime : RaceClock
    , lapImprovement : Int
    , crossingFinishLineInPit : String
    , s1 : Maybe RaceClock -- 2023年のデータで部分的に欠落しているのでMaybeを付けている
    , s1Improvement : Int
    , s2 : Maybe RaceClock -- 2023年のデータで部分的に欠落しているのでMaybeを付けている
    , s2Improvement : Int
    , s3 : Maybe RaceClock -- 2024年のデータで部分的に欠落しているのでMaybeを付けている
    , s3Improvement : Int
    , kph : Float
    , elapsed : RaceClock
    , hour : RaceClock
    , topSpeed : Maybe Float -- 2023年のデータで部分的に欠落しているのでMaybeを付けている
    , driverName : String
    , pitTime : Maybe RaceClock
    , class : Class
    , group : String
    , team : String
    , manufacturer : String
    }


type alias RaceClock =
    Duration



-- DECODER


lapDecoder : Decoder Lap
lapDecoder =
    Decode.succeed Lap
        |> required "carNumber" string
        |> required "driverNumber" int
        |> required "lapNumber" int
        |> required "lapTime" raceClockDecoder
        |> required "lapImprovement" int
        |> required "crossingFinishLineInPit" string
        |> required "s1" (Decode.maybe raceClockDecoder)
        |> required "s1Improvement" int
        |> required "s2" (Decode.maybe raceClockDecoder)
        |> required "s2Improvement" int
        |> required "s3" (Decode.maybe raceClockDecoder)
        |> required "s3Improvement" int
        |> required "kph" float
        |> required "elapsed" raceClockDecoder
        |> required "hour" raceClockDecoder
        |> required "topSpeed" (Decode.map String.toFloat string)
        |> required "driverName" string
        |> required "pitTime" (Decode.maybe raceClockDecoder)
        |> required "class" classDecoder
        |> required "group" string
        |> required "team" string
        |> required "manufacturer" string


raceClockDecoder : Decoder Duration
raceClockDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a RaceClock")


classDecoder : Decoder Class
classDecoder =
    string |> Decode.andThen (Class.fromString >> Json.Decode.Extra.fromMaybe "Expected a Class")
