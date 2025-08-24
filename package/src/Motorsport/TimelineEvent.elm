module Motorsport.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder
    )

{-|

@docs TimelineEvent, EventType, CarEventType
@docs decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (optional, required)
import Motorsport.Car exposing (CarNumber)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)


type alias TimelineEvent =
    { eventTime : Duration, eventType : EventType }


type EventType
    = RaceStart
    | CarEvent CarNumber CarEventType


type CarEventType
    = Start { currentLap : Lap }
    | LapCompleted Int { nextLap : Lap }
    | Retirement
    | Checkered


decoder : Decoder TimelineEvent
decoder =
    Decode.map2 TimelineEvent
        (field "event_time" eventTimeDecoder)
        (field "event_type" eventTypeDecoder)


eventTimeDecoder : Decoder Duration
eventTimeDecoder =
    string
        |> Decode.andThen
            (\str ->
                case Duration.fromString str of
                    Just duration ->
                        Decode.succeed duration

                    Nothing ->
                        Decode.fail ("Invalid duration format: " ++ str)
            )


eventTypeDecoder : Decoder EventType
eventTypeDecoder =
    Decode.oneOf
        [ Decode.map (\_ -> RaceStart)
            (Decode.string
                |> Decode.andThen
                    (\s ->
                        if s == "RaceStart" then
                            Decode.succeed ()

                        else
                            Decode.fail "Expected RaceStart"
                    )
            )
        , Decode.map2 CarEvent
            (field "CarEvent" (Decode.index 0 string))
            (field "CarEvent" (Decode.index 1 carEventTypeDecoder))
        ]


durationDecoder : Decoder Duration
durationDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a Duration")


lapDecoder : Decoder Lap
lapDecoder =
    Decode.succeed Lap
        |> required "car_number" string
        |> required "driver" (Decode.map Driver string)
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
        |> optional "miniSectors" (Decode.maybe miniSectorsDecoder) Nothing


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


type alias RaceClock =
    Duration


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


raceClockDecoder : Decoder Duration
raceClockDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a RaceClock")


carEventTypeDecoder : Decoder CarEventType
carEventTypeDecoder =
    Decode.oneOf
        [ Decode.map Start
            (field "Start"
                (Decode.map (\currentLap -> { currentLap = currentLap })
                    (field "current_lap" lapDecoder)
                )
            )
        , Decode.map2 LapCompleted
            (field "LapCompleted" (field "lap_number" int))
            (field "LapCompleted"
                (Decode.map (\nextLap -> { nextLap = nextLap })
                    (field "next_lap" lapDecoder)
                )
            )
        , Decode.map (\_ -> Retirement)
            (Decode.string
                |> Decode.andThen
                    (\s ->
                        if s == "Retirement" then
                            Decode.succeed ()

                        else
                            Decode.fail "Expected Retirement"
                    )
            )
        , Decode.map (\_ -> Checkered)
            (Decode.string
                |> Decode.andThen
                    (\s ->
                        if s == "Checkered" then
                            Decode.succeed ()

                        else
                            Decode.fail "Expected Checkered"
                    )
            )
        ]
