module Motorsport.TimelineEvent exposing
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
import Json.Decode.Pipeline exposing (optional, required)
import List.Extra
import Motorsport.Car exposing (Car, CarNumber)
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
    | PitIn { lapNumber : Int, duration : Duration }
    | PitOut { lapNumber : Int, duration : Duration }
    | Retirement
    | Checkered



-- BUILD


{-| Build a sorted list of timeline events from a list of cars.

Emits, in this order:

1.  RaceStart at time 0
2.  Per-car Start events at time 0 (with `pitTime` stripped from the embedded lap)
3.  Per-lap LapCompleted events for non-final laps (with `pitTime` stripped from `nextLap`)
4.  PitIn / PitOut events for laps whose `pitTime` is `Just`
5.  Retirement / Checkered for the final lap, depending on the rounded time limit

The result is sorted by `eventTime` (stable).

-}
fromCars : List Car -> List TimelineEvent
fromCars cars =
    let
        timeLimit =
            calcTimeLimit cars

        events =
            [ raceStartEvent ]
                ++ startEvents cars
                ++ lapCompletedEvents cars
                ++ pitEvents cars
                ++ terminalEvents timeLimit cars
    in
    List.sortBy .eventTime events


calcTimeLimit : List Car -> Duration
calcTimeLimit cars =
    cars
        |> List.filterMap (\car -> List.Extra.last car.laps |> Maybe.map .elapsed)
        |> List.maximum
        |> Maybe.map (\t -> (t // (60 * 60 * 1000)) * 60 * 60 * 1000)
        |> Maybe.withDefault 0


raceStartEvent : TimelineEvent
raceStartEvent =
    { eventTime = 0, eventType = RaceStart }


startEvents : List Car -> List TimelineEvent
startEvents cars =
    cars
        |> List.filterMap
            (\car ->
                List.head car.laps
                    |> Maybe.map
                        (\firstLap ->
                            { eventTime = 0
                            , eventType =
                                CarEvent car.metadata.carNumber
                                    (Start { currentLap = stripPitTime firstLap })
                            }
                        )
            )


lapCompletedEvents : List Car -> List TimelineEvent
lapCompletedEvents cars =
    cars
        |> List.concatMap
            (\car ->
                let
                    laps =
                        car.laps

                    pairs =
                        List.map2 Tuple.pair laps (List.drop 1 laps)
                in
                pairs
                    |> List.map
                        (\( lap, nextLap ) ->
                            { eventTime = lap.elapsed
                            , eventType =
                                CarEvent car.metadata.carNumber
                                    (LapCompleted lap.lap { nextLap = stripPitTime nextLap })
                            }
                        )
            )


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
                                            Basics.max 0 (lap.elapsed - pitDuration)
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


terminalEvents : Duration -> List Car -> List TimelineEvent
terminalEvents timeLimit cars =
    cars
        |> List.filterMap
            (\car ->
                List.Extra.last car.laps
                    |> Maybe.map
                        (\finalLap ->
                            let
                                carEventType =
                                    if finalLap.elapsed < timeLimit then
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
        |> optional "pit_time" (Decode.maybe durationDecoder) Nothing
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
