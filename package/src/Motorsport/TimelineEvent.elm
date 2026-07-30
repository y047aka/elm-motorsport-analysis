module Motorsport.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , fromEntrants
    , decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder
    )

{-|

@docs TimelineEvent, EventType, CarEventType
@docs fromEntrants
@docs decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (custom, optional, required)
import List.Extra
import Motorsport.Entrant exposing (CarNumber, Entrant)
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)


type alias TimelineEvent =
    { eventTime : Duration, eventType : EventType }


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

Emits, in this order:

1.  RaceStart at time 0
2.  Per-entrant Start events at time 0 (with `pitTime` stripped from the embedded lap)
3.  A TookLead event each time the car at the front of the field changes
4.  PitIn / PitOut events for laps whose `pitTime` is `Just`
5.  Retirement / Checkered for the final lap, depending on the rounded time limit

The result is sorted by `eventTime` (stable).

What is deliberately *not* here is a per-lap completion event. Emitting one for
every car on every lap put fifteen thousand rows of "car 7 completed lap 112" into
a list meant to be read as the shape of the race -- five in six of everything in
it, saying nothing a reader could follow. The laps themselves are unaffected: they
live on the entrant, where every chart and table already reads them.

-}
fromEntrants : List Entrant -> List TimelineEvent
fromEntrants entrants =
    let
        timeLimit =
            calcTimeLimit entrants

        events =
            [ raceStartEvent ]
                ++ startEvents entrants
                ++ leadChangeEvents entrants
                ++ pitEvents entrants
                ++ terminalEvents timeLimit entrants
    in
    List.sortBy .eventTime events


calcTimeLimit : List Entrant -> Duration
calcTimeLimit entrants =
    entrants
        |> List.filterMap (\entrant -> List.Extra.last entrant.laps |> Maybe.map .elapsed)
        |> List.maximum
        |> Maybe.map (\t -> (t // (60 * 60 * 1000)) * 60 * 60 * 1000)
        |> Maybe.withDefault 0


raceStartEvent : TimelineEvent
raceStartEvent =
    { eventTime = 0, eventType = RaceStart }


startEvents : List Entrant -> List TimelineEvent
startEvents entrants =
    entrants
        |> List.filterMap
            (\entrant ->
                List.head entrant.laps
                    |> Maybe.map
                        (\firstLap ->
                            { eventTime = 0
                            , eventType =
                                CarEvent entrant.metadata.carNumber
                                    (Start { currentLap = stripPitTime firstLap })
                            }
                        )
            )


{-| Who is leading at the end of each lap, in lap order.
-}
type alias Leader =
    { lapNumber : Int, eventTime : Duration, carNumber : CarNumber }


{-| A `TookLead` each time the car at the front of the field changes hands.

The lead is read off `Lap.position`, which the loader assigns per lap by order of
crossing the line, so a change is only ever seen at a lap boundary. That is the
granularity a timing feed reports it at anyway: a car that leads briefly between
two lap lines was never shown as leading.

Whoever leads the opening lap has taken it from nobody, so the first leader is not
an event. Only the changes are.

-}
leadChangeEvents : List Entrant -> List TimelineEvent
leadChangeEvents entrants =
    let
        leaders : List Leader
        leaders =
            entrants
                |> List.concatMap
                    (\entrant ->
                        entrant.laps
                            |> List.filter (\lap -> lap.position == Just leadPosition)
                            |> List.map
                                (\lap ->
                                    { lapNumber = lap.lap
                                    , eventTime = lap.elapsed
                                    , carNumber = entrant.metadata.carNumber
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


pitEvents : List Entrant -> List TimelineEvent
pitEvents entrants =
    entrants
        |> List.concatMap
            (\entrant ->
                entrant.laps
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
                                            CarEvent entrant.metadata.carNumber
                                                (PitIn { lapNumber = lap.lap, duration = pitDuration })
                                      }
                                    , { eventTime = lap.elapsed
                                      , eventType =
                                            CarEvent entrant.metadata.carNumber
                                                (PitOut { lapNumber = lap.lap, duration = pitDuration })
                                      }
                                    ]

                                Nothing ->
                                    []
                        )
            )


terminalEvents : Duration -> List Entrant -> List TimelineEvent
terminalEvents timeLimit entrants =
    entrants
        |> List.filterMap
            (\entrant ->
                List.Extra.last entrant.laps
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
                            , eventType = CarEvent entrant.metadata.carNumber carEventType
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
        |> required "driver" (Decode.map Driver.fromName string)
        |> required "lap" int
        |> required "position" (Decode.maybe int)
        |> required "time" durationDecoder
        |> required "best" durationDecoder
        |> custom sectorsDecoder
        |> required "elapsed" durationDecoder
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
                (field timeKey durationDecoder)
                (field bestKey durationDecoder)
    in
    Decode.map3 (\s1 s2 s3 -> { s1 = s1, s2 = s2, s3 = s3 })
        (sectorTime "sector_1" "s1_best")
        (sectorTime "sector_2" "s2_best")
        (sectorTime "sector_3" "s3_best")


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
