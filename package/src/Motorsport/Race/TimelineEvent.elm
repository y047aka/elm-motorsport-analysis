module Motorsport.Race.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , fromCars
    , decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder
    )

{-|

@docs TimelineEvent, EventType, CarEventType
@docs fromCars
@docs decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (custom, optional, required)
import List.Extra
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)


type alias TimelineEvent =
    { eventTime : Instant, eventType : EventType }


type EventType
    = RaceStart
    | CarEvent CarNumber CarEventType


type CarEventType
    = Start { currentLap : Lap }
    | TookLead
    | PitIn { lapNumber : Int, duration : Duration }
    | PitOut { lapNumber : Int, duration : Duration }
    | Retirement
    | Checkered



-- BUILD


{-| Build a sorted list of timeline events from a race's entry list.

There is deliberately no per-lap completion event: one per car per lap was five
in six of the list, and the laps are on the car already for everything that
reads them.

-}
fromCars : List Car -> List TimelineEvent
fromCars cars =
    let
        timeLimit =
            calcTimeLimit cars

        events =
            [ raceStartEvent ]
                ++ startEvents cars
                ++ leadChangeEvents cars
                ++ pitEvents cars
                ++ terminalEvents timeLimit cars
    in
    List.sortBy (.eventTime >> Instant.toDuration) events


calcTimeLimit : List Car -> Instant
calcTimeLimit cars =
    let
        hour =
            60 * 60 * 1000

        lastLap =
            cars
                |> List.filterMap (\car -> List.Extra.last car.laps |> Maybe.map .elapsed)
                |> List.foldl Instant.later Instant.raceStart
    in
    Instant.fromDuration ((Instant.toDuration lastLap // hour) * hour)


raceStartEvent : TimelineEvent
raceStartEvent =
    { eventTime = Instant.raceStart, eventType = RaceStart }


startEvents : List Car -> List TimelineEvent
startEvents cars =
    cars
        |> List.filterMap
            (\car ->
                List.head car.laps
                    |> Maybe.map
                        (\firstLap ->
                            { eventTime = Instant.raceStart
                            , eventType =
                                CarEvent car.metadata.carNumber
                                    (Start { currentLap = stripPitTime firstLap })
                            }
                        )
            )


{-| Who is leading at the end of each lap, in lap order.
-}
type alias Leader =
    { lapNumber : Int, eventTime : Instant, carNumber : CarNumber }


{-| A `TookLead` each time the car at the front of the field changes hands.

The lead is read off `Lap.position`, which the loader -- not the source data --
assigns per lap by order of crossing the line, so a change is only ever seen at
a lap boundary. Whoever leads the opening lap has taken it from nobody, so the
first leader is not an event.

-}
leadChangeEvents : List Car -> List TimelineEvent
leadChangeEvents cars =
    let
        leaders : List Leader
        leaders =
            cars
                |> List.concatMap
                    (\car ->
                        car.laps
                            |> List.filter (\lap -> lap.position == Just leadPosition)
                            |> List.map
                                (\lap ->
                                    { lapNumber = lap.lap
                                    , eventTime = lap.elapsed
                                    , carNumber = car.metadata.carNumber
                                    }
                                )
                    )
                |> List.sortBy .lapNumber
    in
    List.map2 Tuple.pair leaders (List.drop 1 leaders)
        |> List.filterMap
            (\( previous, current ) ->
                if previous.carNumber == current.carNumber then
                    Nothing

                else
                    Just
                        { eventTime = current.eventTime
                        , eventType = CarEvent current.carNumber TookLead
                        }
            )


{-| `Lap.position` counts from zero; see `Data.Wec.Laps.assignPositions`.
-}
leadPosition : Int
leadPosition =
    0


pitEvents : List Car -> List TimelineEvent
pitEvents cars =
    cars
        |> List.concatMap
            (\car ->
                car.laps
                    |> List.concatMap
                        (\lap ->
                            case lap.pitTime of
                                Just pitDuration ->
                                    let
                                        pitInTime =
                                            Instant.subtract pitDuration lap.elapsed
                                    in
                                    [ { eventTime = pitInTime
                                      , eventType =
                                            CarEvent car.metadata.carNumber
                                                (PitIn { lapNumber = lap.lap, duration = pitDuration })
                                      }
                                    , { eventTime = lap.elapsed
                                      , eventType =
                                            CarEvent car.metadata.carNumber
                                                (PitOut { lapNumber = lap.lap, duration = pitDuration })
                                      }
                                    ]

                                Nothing ->
                                    []
                        )
            )


terminalEvents : Instant -> List Car -> List TimelineEvent
terminalEvents timeLimit cars =
    cars
        |> List.filterMap
            (\car ->
                List.Extra.last car.laps
                    |> Maybe.map
                        (\finalLap ->
                            let
                                carEventType =
                                    if Instant.compare finalLap.elapsed timeLimit == LT then
                                        Retirement

                                    else
                                        Checkered
                            in
                            { eventTime = finalLap.elapsed
                            , eventType = CarEvent car.metadata.carNumber carEventType
                            }
                        )
            )


stripPitTime : Lap -> Lap
stripPitTime lap =
    { lap | pitTime = Nothing }



-- DECODE


decoder : Decoder TimelineEvent
decoder =
    Decode.map2 TimelineEvent
        (field "event_time" eventTimeDecoder)
        (field "event_type" eventTypeDecoder)


eventTimeDecoder : Decoder Instant
eventTimeDecoder =
    Instant.decoder


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


{-| A lap or sector time the source data may not have recorded; see
[`Lap.recorded`](Motorsport-Lap#recorded).
-}
recordedDurationDecoder : Decoder (Maybe Duration)
recordedDurationDecoder =
    Decode.map Lap.recorded durationDecoder


lapDecoder : Decoder Lap
lapDecoder =
    Decode.succeed Lap
        |> required "car_number" string
        |> required "driver" (Decode.map Driver.fromName string)
        |> required "lap" int
        |> required "position" (Decode.maybe int)
        |> required "time" recordedDurationDecoder
        |> required "best" recordedDurationDecoder
        |> custom sectorsDecoder
        |> required "elapsed" Instant.decoder
        |> optional "pit_time" (Decode.maybe durationDecoder) Nothing
        |> optional "miniSectors" (Decode.maybe miniSectorsDecoder) Nothing


{-| The wire format still spells the sectors out flat, and pairs each time with
its best under a differently shaped key. This is where that stops.
-}
sectorsDecoder : Decoder Lap.SectorTimes
sectorsDecoder =
    let
        sectorTime timeKey bestKey =
            Decode.map2 (\time personalBest -> { time = time, personalBest = personalBest })
                (field timeKey recordedDurationDecoder)
                (field bestKey recordedDurationDecoder)
    in
    Decode.map3 (\s1 s2 s3 -> { s1 = s1, s2 = s2, s3 = s3 })
        (sectorTime "sector_1" "s1_best")
        (sectorTime "sector_2" "s2_best")
        (sectorTime "sector_3" "s3_best")


{-| The mini-sector counterpart of [`sectorsDecoder`](#sectorsDecoder).

Built against [`ByMiniSector`](Motorsport-Circuit-LeMans#ByMiniSector) itself
rather than a record shaped like it, so that a field added to a
[`MiniSectorTime`](Motorsport-Lap#MiniSectorTime) is a decoder that stops
compiling rather than one that quietly decodes into the wrong type. That each
key lands in the field named after it is `TimelineEventTest`'s job.

-}
miniSectorsDecoder : Decoder Lap.MiniSectors
miniSectorsDecoder =
    Decode.succeed LeMans.ByMiniSector
        |> required "scl2" miniSectorTimeDecoder
        |> required "z4" miniSectorTimeDecoder
        |> required "ip1" miniSectorTimeDecoder
        |> required "z12" miniSectorTimeDecoder
        |> required "sclc" miniSectorTimeDecoder
        |> required "a7_1" miniSectorTimeDecoder
        |> required "ip2" miniSectorTimeDecoder
        |> required "a8_1" miniSectorTimeDecoder
        |> required "sclb" miniSectorTimeDecoder
        |> required "porin" miniSectorTimeDecoder
        |> required "porout" miniSectorTimeDecoder
        |> required "pitref" miniSectorTimeDecoder
        |> required "scl1" miniSectorTimeDecoder
        |> required "fordout" miniSectorTimeDecoder
        |> required "fl" miniSectorTimeDecoder


{-| `elapsed` on the wire is what a `Lap` calls `elapsedInLap`: the running
total from the line, not the race clock a `Lap.elapsed` carries.
-}
miniSectorTimeDecoder : Decoder Lap.MiniSectorTime
miniSectorTimeDecoder =
    Decode.succeed Lap.MiniSectorTime
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
        , Decode.map (\_ -> TookLead)
            (Decode.string
                |> Decode.andThen
                    (\s ->
                        if s == "TookLead" then
                            Decode.succeed ()

                        else
                            Decode.fail "Expected TookLead"
                    )
            )
        , Decode.map PitIn
            (field "PitIn"
                (Decode.map2 (\lapNumber duration -> { lapNumber = lapNumber, duration = duration })
                    (field "lap_number" int)
                    (field "duration" durationDecoder)
                )
            )
        , Decode.map PitOut
            (field "PitOut"
                (Decode.map2 (\lapNumber duration -> { lapNumber = lapNumber, duration = duration })
                    (field "lap_number" int)
                    (field "duration" durationDecoder)
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
