module Data.Wec exposing
    ( Event
    , eventDecoder
    )

{-|

@docs Event
@docs eventDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, float, int, list, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (optional, required)
import Motorsport.Car as Car exposing (Car, Status(..))
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.LapExtractor as LapExtractor
import Motorsport.Manufacturer as Manufacturer
import Motorsport.TimelineEvent as TimelineEvent exposing (TimelineEvent)


type alias Event =
    { name : String
    , laps : List Lap
    , preprocessed : List Car
    , timelineEvents : List TimelineEvent
    }


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
    , miniSectors : Maybe MiniSectors
    }


type alias RaceClock =
    Duration


type alias MiniSectors =
    { scl2 : MiniSector
    , z4 : MiniSector
    , ip1 : MiniSector
    , z12 : MiniSector
    , sclc : MiniSector
    , a7_1 : MiniSector
    , ip2 : MiniSector
    , a8_1 : MiniSector
    , sclb : MiniSector
    , porin : MiniSector
    , porout : MiniSector
    , pitref : MiniSector
    , scl1 : MiniSector
    , fordout : MiniSector
    , fl : MiniSector
    }


type alias MiniSector =
    { time : Maybe RaceClock
    , elapsed : Maybe RaceClock
    , best : Maybe RaceClock
    }



-- DECODER


eventDecoder : Decoder Event
eventDecoder =
    Decode.map4 Event
        (field "name" string)
        (field "laps" (list lapDecoder))
        (Decode.map2 restoreLapsFromTimelineEvents
            (field "timeline_events" (list TimelineEvent.decoder))
            (field "preprocessed" (list carDecoder))
        )
        (field "timeline_events" (list TimelineEvent.decoder))


{-| timeline\_eventsからlapsを復元してpreprocessedのCarsに適用する
-}
restoreLapsFromTimelineEvents : List TimelineEvent -> List Car -> List Car
restoreLapsFromTimelineEvents timelineEvents cars =
    LapExtractor.extractLapsFromTimelineEvents timelineEvents cars


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
        |> optional "miniSectors" (Decode.maybe miniSectorsDecoder) Nothing


raceClockDecoder : Decoder Duration
raceClockDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a RaceClock")


classDecoder : Decoder Class
classDecoder =
    string |> Decode.andThen (Class.fromString >> Json.Decode.Extra.fromMaybe "Expected a Class")


miniSectorsDecoder : Decoder MiniSectors
miniSectorsDecoder =
    Decode.succeed MiniSectors
        |> required "scl2" miniSectorDecoder
        |> required "z4" miniSectorDecoder
        |> required "ip1" miniSectorDecoder
        |> required "z12" miniSectorDecoder
        |> required "sclc" miniSectorDecoder
        |> required "a7_1" miniSectorDecoder
        |> required "ip2" miniSectorDecoder
        |> required "a8_1" miniSectorDecoder
        |> required "sclb" miniSectorDecoder
        |> required "porin" miniSectorDecoder
        |> required "porout" miniSectorDecoder
        |> required "pitref" miniSectorDecoder
        |> required "scl1" miniSectorDecoder
        |> required "fordout" miniSectorDecoder
        |> required "fl" miniSectorDecoder


miniSectorDecoder : Decoder MiniSector
miniSectorDecoder =
    Decode.succeed MiniSector
        |> required "time" (Decode.maybe raceClockDecoder)
        |> required "elapsed" (Decode.maybe raceClockDecoder)
        |> required "best" (Decode.maybe raceClockDecoder)


carDecoder : Decoder Car
carDecoder =
    Decode.map7 Car
        metadataDecoder
        (field "startPosition" int)
        (Decode.succeed [])
        (Decode.succeed Nothing)
        (Decode.succeed Nothing)
        (Decode.succeed PreRace)
        (Decode.succeed Nothing)


metadataDecoder : Decoder Car.Metadata
metadataDecoder =
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
