module Motorsport.Race.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , fromCars
    )

{-|

@docs TimelineEvent, EventType, CarEventType
@docs fromCars

-}

import List.Extra
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car exposing (Car, CarNumber)


type alias TimelineEvent =
    { eventTime : Instant, eventType : EventType }


type EventType
    = RaceStart
    | CarEvent CarNumber CarEventType


type CarEventType
    = Start
    | TookLead
    | PitIn { lapNumber : Int, duration : Duration }
    | PitOut { lapNumber : Int, duration : Duration }
    | Retirement
    | Checkered



-- BUILD


{-| Build a sorted list of timeline events from a race's entry list.

`timeLimit` decides whether a car's last lap was the flag or a retirement, and
is passed in rather than read off the laps -- see
[`Race.fromCars`](Motorsport-Race#fromCars).

There is deliberately no per-lap completion event: one per car per lap was five
in six of the list, and the laps are on the car already for everything that
reads them.

-}
fromCars : { timeLimit : Instant } -> List Car -> List TimelineEvent
fromCars { timeLimit } cars =
    let
        events =
            [ raceStartEvent ]
                ++ startEvents cars
                ++ leadChangeEvents cars
                ++ pitEvents cars
                ++ terminalEvents timeLimit cars
    in
    List.sortBy (.eventTime >> Instant.toDuration) events


raceStartEvent : TimelineEvent
raceStartEvent =
    { eventTime = Instant.raceStart, eventType = RaceStart }


startEvents : List Car -> List TimelineEvent
startEvents cars =
    cars
        |> List.filter (\car -> not (List.isEmpty car.laps))
        |> List.map
            (\car ->
                { eventTime = Instant.raceStart
                , eventType = CarEvent car.metadata.carNumber Start
                }
            )


{-| Who is leading at the end of each lap, in lap order.
-}
type alias Leader =
    { lapNumber : Int, eventTime : Instant, carNumber : CarNumber }


{-| A `TookLead` each time the car at the front of the field changes hands.

The lead is read off `Lap.position`, which is the field's order at that lap, so
a change is only ever seen at a lap boundary. Whoever leads the opening lap has
taken it from nobody, so the first leader is not an event.

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


{-| `Lap.position` counts from zero.
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
