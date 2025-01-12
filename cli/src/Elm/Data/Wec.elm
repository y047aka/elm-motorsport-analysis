module Data.Wec exposing
    ( Lap
    , carEncoder
    , getLaps
    , lapEncoder
    )

import Csv.Decode as Decode exposing (Decoder, FieldNames(..), field, float, int, pipeline, string)
import Data.Wec.Decoder as Wec
import Http exposing (Error(..), Expect, Response(..))
import Json.Encode as JE
import Json.Encode.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap


type alias Lap =
    Wec.Lap


endpoint : String
endpoint =
    "https://raw.githubusercontent.com/y047aka/elm-motorsport-analysis/refs/heads/main/app/static/wec_2024"


type alias RaceClock =
    Duration


lapDecoder : Decoder Lap
lapDecoder =
    Decode.into Wec.Lap
        |> pipeline (field "NUMBER" string)
        |> pipeline (field "DRIVER_NUMBER" int)
        |> pipeline (field "LAP_NUMBER" int)
        |> pipeline (field "LAP_TIME" raceClockDecoder)
        |> pipeline (field "LAP_IMPROVEMENT" int)
        |> pipeline (field "CROSSING_FINISH_LINE_IN_PIT" string)
        |> pipeline (field "S1" <| Decode.blank raceClockDecoder)
        |> pipeline (field "S1_IMPROVEMENT" int)
        |> pipeline (field "S2" <| Decode.blank raceClockDecoder)
        |> pipeline (field "S2_IMPROVEMENT" int)
        |> pipeline (field "S3" <| Decode.blank raceClockDecoder)
        |> pipeline (field "S3_IMPROVEMENT" int)
        |> pipeline (field "KPH" float)
        |> pipeline (field "ELAPSED" raceClockDecoder)
        |> pipeline (field "HOUR" raceClockDecoder)
        |> pipeline (field "TOP_SPEED" <| Decode.blank Decode.float)
        |> pipeline (field "DRIVER_NAME" string)
        |> pipeline (field "PIT_TIME" <| Decode.blank raceClockDecoder)
        |> pipeline (field "CLASS" classDecoder)
        |> pipeline (field "GROUP" string)
        |> pipeline (field "TEAM" string)
        |> pipeline (field "MANUFACTURER" string)


raceClockDecoder : Decoder RaceClock
raceClockDecoder =
    string |> Decode.andThen (Duration.fromString >> Decode.fromMaybe "Expected a RaceClock")


classDecoder : Decoder Class
classDecoder =
    string |> Decode.andThen (Class.fromString >> Decode.fromMaybe "Expected a Class")


getLaps : String -> (Result Http.Error (List Lap) -> msg) -> Cmd msg
getLaps eventId msg =
    Http.get
        { url =
            [ endpoint, eventId ++ ".csv" ]
                |> String.join "/"
        , expect = expectCsv msg lapDecoder
        }


expectCsv : (Result Http.Error (List a) -> msg) -> Decoder a -> Expect msg
expectCsv toMsg decoder_ =
    let
        resolve : (body -> Result String (List a)) -> Response body -> Result Error (List a)
        resolve toResult response =
            case response of
                BadUrl_ url ->
                    Err (BadUrl url)

                Timeout_ ->
                    Err Timeout

                NetworkError_ ->
                    Err NetworkError

                BadStatus_ metadata _ ->
                    Err (BadStatus metadata.statusCode)

                GoodStatus_ _ body ->
                    Result.mapError BadBody (toResult body)
    in
    Http.expectStringResponse toMsg <|
        resolve
            (Decode.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow decoder_
                >> Result.mapError Decode.errorToString
            )



-- ENCODER


lapEncoder : Lap -> JE.Value
lapEncoder lap =
    JE.object
        [ ( "carNumber", JE.string lap.carNumber )
        , ( "driverNumber", JE.int lap.driverNumber )
        , ( "lapNumber", JE.int lap.lapNumber )
        , ( "lapTime", JE.string (Duration.toString lap.lapTime) )
        , ( "lapImprovement", JE.int lap.lapImprovement )
        , ( "crossingFinishLineInPit", JE.string lap.crossingFinishLineInPit )
        , ( "s1", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.s1) )
        , ( "s1Improvement", JE.int lap.s1Improvement )
        , ( "s2", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.s2) )
        , ( "s2Improvement", JE.int lap.s2Improvement )
        , ( "s3", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.s3) )
        , ( "s3Improvement", JE.int lap.s3Improvement )
        , ( "kph", JE.float lap.kph )
        , ( "elapsed", JE.string (Duration.toString lap.elapsed) )
        , ( "hour", JE.string (Duration.toString lap.hour) )
        , ( "topSpeed", JE.string (Maybe.withDefault "" <| Maybe.map String.fromFloat lap.topSpeed) )
        , ( "driverName", JE.string lap.driverName )
        , ( "pitTime", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.pitTime) )
        , ( "class", JE.string <| Class.toString lap.class )
        , ( "group", JE.string lap.group )
        , ( "team", JE.string lap.team )
        , ( "manufacturer", JE.string lap.manufacturer )
        ]


carEncoder : Car -> JE.Value
carEncoder car =
    JE.object
        [ ( "carNumber", JE.string car.carNumber )
        , ( "drivers", JE.list driverEncoder car.drivers )
        , ( "class", JE.string <| Class.toString car.class )
        , ( "group", JE.string car.group )
        , ( "team", JE.string car.team )
        , ( "manufacturer", JE.string car.manufacturer )
        , ( "startPosition", JE.int car.startPosition )
        , ( "laps", JE.list lapEncoderForPreprocessed car.laps )
        , ( "currentLap", Json.Encode.Extra.maybe lapEncoderForPreprocessed car.currentLap )
        , ( "lastLap", Json.Encode.Extra.maybe lapEncoderForPreprocessed car.lastLap )
        ]


driverEncoder : Driver -> JE.Value
driverEncoder driver =
    JE.object
        [ ( "name", JE.string driver.name )
        , ( "isCurrentDriver", JE.bool driver.isCurrentDriver )
        ]


lapEncoderForPreprocessed : Motorsport.Lap.Lap -> JE.Value
lapEncoderForPreprocessed lap =
    JE.object
        [ ( "carNumber", JE.string lap.carNumber )
        , ( "driver", JE.string lap.driver )
        , ( "lap", JE.int lap.lap )
        , ( "position", Json.Encode.Extra.maybe JE.int lap.position )
        , ( "time", JE.string (Duration.toString lap.time) )
        , ( "best", JE.string (Duration.toString lap.best) )
        , ( "sector_1", JE.string (Duration.toString lap.sector_1) )
        , ( "sector_2", JE.string (Duration.toString lap.sector_2) )
        , ( "sector_3", JE.string (Duration.toString lap.sector_3) )
        , ( "s1_best", JE.string (Duration.toString lap.s1_best) )
        , ( "s2_best", JE.string (Duration.toString lap.s2_best) )
        , ( "s3_best", JE.string (Duration.toString lap.s3_best) )
        , ( "elapsed", JE.string (Duration.toString lap.elapsed) )
        ]
