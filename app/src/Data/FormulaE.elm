module Data.FormulaE exposing
    ( Event
    , eventDecoder, lapDecoder
    )

{-|

@docs Event
@docs eventDecoder, lapDecoder

-}

import Json.Decode as Decode exposing (Decoder, bool, field, float, int, list, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (hardcoded, required)
import Motorsport.Car as Car exposing (Status(..))
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.TimelineEvent as TimelineEvent exposing (TimelineEvent)


type alias Event =
    { name : String
    , laps : List Lap
    , startingGrid : List StartingGridItem
    , timelineEvents : List TimelineEvent
    }


type alias StartingGridItem =
    { position : Int
    , car : Car.Metadata
    }


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
    , s1Large : String
    , s2Large : String
    , s3Large : String
    , topSpeed : Maybe Float
    , driverName : String
    , pitTime : Maybe RaceClock
    , team : String
    , manufacturer : String
    , power : String
    , fanboost : Bool
    , attackMode : Bool
    }


type alias RaceClock =
    Duration



-- DECODER


eventDecoder : Decoder Event
eventDecoder =
    Decode.map4 Event
        (field "name" string)
        (field "laps" (list lapDecoder))
        (field "startingGrid" (list startingGridItemDecoder))
        (field "timelineEvents" (list TimelineEvent.decoder))


startingGridItemDecoder : Decoder StartingGridItem
startingGridItemDecoder =
    Decode.map2 StartingGridItem
        (field "position" int)
        (field "car" carMetadataDecoder)


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
        -- TODO: 不要であれば削除
        |> hardcoded "s1Large"
        |> hardcoded "s2Large"
        |> hardcoded "s3Large"
        |> required "topSpeed" (Decode.map String.toFloat string)
        |> required "driverName" string
        |> required "pitTime" (Decode.maybe raceClockDecoder)
        |> required "team" string
        |> required "manufacturer" string
        |> required "power" string
        |> required "fanboost" bool
        |> required "attackMode" bool


raceClockDecoder : Decoder Duration
raceClockDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a RaceClock")


classDecoder : Decoder Class
classDecoder =
    -- Formula Eではクラスがないので常にNoneにしておく
    Decode.succeed Class.none


carMetadataDecoder : Decoder Car.Metadata
carMetadataDecoder =
    Decode.succeed Car.Metadata
        |> required "carNumber" string
        |> required "drivers" (Decode.list driverDecoder)
        |> required "class" classDecoder
        |> required "group" string
        |> required "team" string
        |> required "manufacturer" (string |> Decode.map Manufacturer.fromString)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver
        (field "name" string)
