module Data.Lap.Wec exposing (Lap, lapDecoder)

import Csv.Decode as Decode exposing (Decoder, field, float, int, pipeline, string)
import Data.Class as Class exposing (Class(..))
import Data.Old.RaceClock as RaceClock exposing (RaceClock)


type alias Lap =
    { carNumber : Int
    , driverNumber : Int
    , lapNumber : Int
    , lapTime : RaceClock
    , lapImprovement : Int
    , crossingFinishLineInPit : String
    , s1 : RaceClock
    , s1Improvement : Int
    , s2 : RaceClock
    , s2Improvement : Int
    , s3 : RaceClock
    , s3Improvement : Int
    , kph : Float
    , elapsed : RaceClock
    , hour : RaceClock
    , topSpeed : Float
    , driverName : String
    , pitTime : Maybe RaceClock
    , class : Class
    , group : String
    , team : String
    , manufacturer : String
    }


lapDecoder : Decoder Lap
lapDecoder =
    let
        raceClockDecoder : Decoder RaceClock
        raceClockDecoder =
            string |> Decode.andThen (RaceClock.fromString >> Decode.fromMaybe "Expected a RaceClock")

        classDecoder : Decoder Class
        classDecoder =
            string |> Decode.andThen (Class.fromString >> Decode.fromMaybe "Expected a Class")
    in
    Decode.into Lap
        |> pipeline (field "NUMBER" int)
        |> pipeline (field "DRIVER_NUMBER" int)
        |> pipeline (field "LAP_NUMBER" int)
        |> pipeline (field "LAP_TIME" raceClockDecoder)
        |> pipeline (field "LAP_IMPROVEMENT" int)
        |> pipeline (field "CROSSING_FINISH_LINE_IN_PIT" string)
        |> pipeline (field "S1" raceClockDecoder)
        |> pipeline (field "S1_IMPROVEMENT" int)
        |> pipeline (field "S2" raceClockDecoder)
        |> pipeline (field "S2_IMPROVEMENT" int)
        |> pipeline (field "S3" raceClockDecoder)
        |> pipeline (field "S3_IMPROVEMENT" int)
        |> pipeline (field "KPH" float)
        |> pipeline (field "ELAPSED" raceClockDecoder)
        |> pipeline (field "HOUR" raceClockDecoder)
        |> pipeline (field "TOP_SPEED" float)
        |> pipeline (field "DRIVER_NAME" string)
        |> pipeline (field "PIT_TIME" <| Decode.blank raceClockDecoder)
        |> pipeline (field "CLASS" classDecoder)
        |> pipeline (field "GROUP" string)
        |> pipeline (field "TEAM" string)
        |> pipeline (field "MANUFACTURER" string)
