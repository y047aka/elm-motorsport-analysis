module Data_Cli.LeMans24h exposing
    ( Lap
    , getLaps
    , lapEncoder, carEncoder
    )

{-|

@docs Lap
@docs getLaps
@docs lapEncoder, carEncoder

-}

import Csv.Decode as Decode exposing (Decoder, FieldNames(..), field, float, int, pipeline, string)
import Http exposing (Error(..), Expect, Response(..))
import Json.Encode as JE
import Json.Encode.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap


type alias Lap =
    { carNumber : String
    , driverNumber : Int
    , lapNumber : Int
    , lapTime : RaceClock
    , lapImprovement : Int
    , crossingFinishLineInPit : String
    , s1 : Maybe RaceClock
    , s1Improvement : Int
    , s2 : Maybe RaceClock
    , s2Improvement : Int
    , s3 : Maybe RaceClock
    , s3Improvement : Int
    , kph : Float
    , elapsed : RaceClock
    , hour : RaceClock
    , topSpeed : Maybe Float
    , driverName : String
    , pitTime : Maybe RaceClock
    , class : Class
    , group : String
    , team : String
    , manufacturer : String

    -- MiniSectors
    , scl2_time : Maybe RaceClock
    , scl2_elapsed : Maybe RaceClock
    , z4_time : Maybe RaceClock
    , z4_elapsed : Maybe RaceClock
    , ip1_time : Maybe RaceClock
    , ip1_elapsed : Maybe RaceClock
    , z12_time : Maybe RaceClock
    , z12_elapsed : Maybe RaceClock
    , sclc_time : Maybe RaceClock
    , sclc_elapsed : Maybe RaceClock
    , a7_1_time : Maybe RaceClock
    , a7_1_elapsed : Maybe RaceClock
    , ip2_time : Maybe RaceClock
    , ip2_elapsed : Maybe RaceClock
    , a8_1_time : Maybe RaceClock
    , a8_1_elapsed : Maybe RaceClock
    , sclb_time : Maybe RaceClock
    , sclb_elapsed : Maybe RaceClock
    , porin_time : Maybe RaceClock
    , porin_elapsed : Maybe RaceClock
    , porout_time : Maybe RaceClock
    , porout_elapsed : Maybe RaceClock
    , pitref_time : Maybe RaceClock
    , pitref_elapsed : Maybe RaceClock
    , scl1_time : Maybe RaceClock
    , scl1_elapsed : Maybe RaceClock
    , fordout_time : Maybe RaceClock
    , fordout_elapsed : Maybe RaceClock
    , fl_time : Maybe RaceClock
    , fl_elapsed : Maybe RaceClock
    }


type alias RaceClock =
    Duration


endpoint : String
endpoint =
    "https://raw.githubusercontent.com/y047aka/elm-motorsport-analysis/refs/heads/main/app/static/wec/2025"


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



-- DECODER


lapDecoder : Decoder Lap
lapDecoder =
    Decode.into Lap
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
        |> pipeline (field "SCL2_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "SCL2_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "Z4_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "Z4_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "IP1_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "IP1_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "Z12_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "Z12_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "SCLC_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "SCLC_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "A7-1_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "A7-1_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "IP2_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "IP2_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "A8-1_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "A8-1_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "SCLB_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "SCLB_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "PORIN_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "PORIN_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "POROUT_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "POROUT_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "PITREF_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "PITREF_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "SCL1_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "SCL1_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "FORDOUT_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "FORDOUT_elapsed" <| Decode.blank raceClockDecoder)
        |> pipeline (field "FL_time" <| Decode.blank raceClockDecoder)
        |> pipeline (field "FL_elapsed" <| Decode.blank raceClockDecoder)


raceClockDecoder : Decoder RaceClock
raceClockDecoder =
    string |> Decode.andThen (Duration.fromString >> Decode.fromMaybe "Expected a RaceClock")


classDecoder : Decoder Class
classDecoder =
    string |> Decode.andThen (Class.fromString >> Decode.fromMaybe "Expected a Class")



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
        , ( "miniSectors", miniSectorsEncoder lap )
        ]


miniSectorsEncoder : Lap -> JE.Value
miniSectorsEncoder l =
    JE.object
        [ ( "scl2", miniSectorEncoder l.scl2_time l.scl2_elapsed )
        , ( "z4", miniSectorEncoder l.z4_time l.z4_elapsed )
        , ( "ip1", miniSectorEncoder l.ip1_time l.ip1_elapsed )
        , ( "z12", miniSectorEncoder l.z12_time l.z12_elapsed )
        , ( "sclc", miniSectorEncoder l.sclc_time l.sclc_elapsed )
        , ( "a7_1", miniSectorEncoder l.a7_1_time l.a7_1_elapsed )
        , ( "ip2", miniSectorEncoder l.ip2_time l.ip2_elapsed )
        , ( "a8_1", miniSectorEncoder l.a8_1_time l.a8_1_elapsed )
        , ( "sclb", miniSectorEncoder l.sclb_time l.sclb_elapsed )
        , ( "porin", miniSectorEncoder l.porin_time l.porin_elapsed )
        , ( "porout", miniSectorEncoder l.porout_time l.porout_elapsed )
        , ( "pitref", miniSectorEncoder l.pitref_time l.pitref_elapsed )
        , ( "scl1", miniSectorEncoder l.scl1_time l.scl1_elapsed )
        , ( "fordout", miniSectorEncoder l.fordout_time l.fordout_elapsed )
        , ( "fl", miniSectorEncoder l.fl_time l.fl_elapsed )
        ]


miniSectorEncoder : Maybe RaceClock -> Maybe RaceClock -> JE.Value
miniSectorEncoder time elapsed =
    JE.object
        [ ( "time", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString time) )
        , ( "elapsed", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString elapsed) )
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
        , ( "miniSectors", miniSectorsEncoderForPreprocessed lap )
        ]


miniSectorsEncoderForPreprocessed : Motorsport.Lap.Lap -> JE.Value
miniSectorsEncoderForPreprocessed l =
    let
        { scl2, z4, ip1, z12, sclc, a7_1, ip2, a8_1, sclb, porin, porout, pitref, scl1, fordout, fl } =
            l.miniSectors
                |> Maybe.withDefault
                    { scl2 = { time = Nothing, elapsed = Nothing }
                    , z4 = { time = Nothing, elapsed = Nothing }
                    , ip1 = { time = Nothing, elapsed = Nothing }
                    , z12 = { time = Nothing, elapsed = Nothing }
                    , sclc = { time = Nothing, elapsed = Nothing }
                    , a7_1 = { time = Nothing, elapsed = Nothing }
                    , ip2 = { time = Nothing, elapsed = Nothing }
                    , a8_1 = { time = Nothing, elapsed = Nothing }
                    , sclb = { time = Nothing, elapsed = Nothing }
                    , porin = { time = Nothing, elapsed = Nothing }
                    , porout = { time = Nothing, elapsed = Nothing }
                    , pitref = { time = Nothing, elapsed = Nothing }
                    , scl1 = { time = Nothing, elapsed = Nothing }
                    , fordout = { time = Nothing, elapsed = Nothing }
                    , fl = { time = Nothing, elapsed = Nothing }
                    }
    in
    JE.object
        [ ( "scl2", miniSectorEncoder scl2.time scl2.elapsed )
        , ( "z4", miniSectorEncoder z4.time z4.elapsed )
        , ( "ip1", miniSectorEncoder ip1.time ip1.elapsed )
        , ( "z12", miniSectorEncoder z12.time z12.elapsed )
        , ( "sclc", miniSectorEncoder sclc.time sclc.elapsed )
        , ( "a7_1", miniSectorEncoder a7_1.time a7_1.elapsed )
        , ( "ip2", miniSectorEncoder ip2.time ip2.elapsed )
        , ( "a8_1", miniSectorEncoder a8_1.time a8_1.elapsed )
        , ( "sclb", miniSectorEncoder sclb.time sclb.elapsed )
        , ( "porin", miniSectorEncoder porin.time porin.elapsed )
        , ( "porout", miniSectorEncoder porout.time porout.elapsed )
        , ( "pitref", miniSectorEncoder pitref.time pitref.elapsed )
        , ( "scl1", miniSectorEncoder scl1.time scl1.elapsed )
        , ( "fordout", miniSectorEncoder fordout.time fordout.elapsed )
        , ( "fl", miniSectorEncoder fl.time fl.elapsed )
        ]
