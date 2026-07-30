module Motorsport.Car.StatusIndex exposing
    ( StatusIndex
    , empty, fromTimelineEvents
    , statusAt
    )

{-| Every moment a car's status changes, collected once from the race timeline.

A status is not something the race control accumulates as the clock runs -- it is
a function of the race and the elapsed time. This index makes that function cheap:
see [`ChangePoints`](Motorsport-ChangePoints), one set of them per car.

@docs StatusIndex
@docs empty, fromTimelineEvents
@docs statusAt

-}

import Dict exposing (Dict)
import Motorsport.Car as Car
import Motorsport.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Duration exposing (Duration)
import Motorsport.Entrant exposing (CarNumber)
import Motorsport.TimelineEvent as TimelineEvent exposing (TimelineEvent)


{-| The change points of every car that has any, keyed by car number.

A car missing from the index -- or one whose earliest change is still ahead of the
clock -- has not taken the start yet, and reads back as `PreRace`.

-}
type StatusIndex
    = StatusIndex (Dict CarNumber (ChangePoints Car.Status))


{-| An index over no race at all. Every car reads back as `PreRace`.
-}
empty : StatusIndex
empty =
    StatusIndex Dict.empty


{-| Build the index from a race's timeline.

Only the events that move a car between statuses are kept; lap completions and the
race start itself leave the status where it was.

-}
fromTimelineEvents : List TimelineEvent -> StatusIndex
fromTimelineEvents events =
    events
        |> List.foldl collect Dict.empty
        |> Dict.map (\_ changes -> ChangePoints.fromList (List.reverse changes))
        |> StatusIndex


collect :
    TimelineEvent
    -> Dict CarNumber (List ( Duration, Car.Status ))
    -> Dict CarNumber (List ( Duration, Car.Status ))
collect { eventTime, eventType } acc =
    case statusChange eventType of
        Just ( carNumber, status ) ->
            Dict.update carNumber
                (\collected ->
                    Just (( eventTime, status ) :: Maybe.withDefault [] collected)
                )
                acc

        Nothing ->
            acc


statusChange : TimelineEvent.EventType -> Maybe ( CarNumber, Car.Status )
statusChange eventType =
    case eventType of
        TimelineEvent.RaceStart ->
            Nothing

        TimelineEvent.CarEvent carNumber (TimelineEvent.Start _) ->
            Just ( carNumber, Car.Racing )

        TimelineEvent.CarEvent carNumber (TimelineEvent.PitIn _) ->
            Just ( carNumber, Car.InPit )

        TimelineEvent.CarEvent carNumber (TimelineEvent.PitOut _) ->
            Just ( carNumber, Car.Racing )

        TimelineEvent.CarEvent carNumber TimelineEvent.Retirement ->
            Just ( carNumber, Car.Retired )

        TimelineEvent.CarEvent carNumber TimelineEvent.Checkered ->
            Just ( carNumber, Car.Checkered )

        TimelineEvent.CarEvent _ (TimelineEvent.LapCompleted _ _) ->
            Nothing


{-| The status a car holds at a given point in the race.

Where a pit exit and the chequered flag land on the same instant the flag wins,
because the timeline lists it later -- see
[`ChangePoints.fromList`](Motorsport-ChangePoints#fromList).

    StatusIndex.statusAt { elapsed = 3600000 } "7" index
    -- Racing, InPit, Retired, ...

-}
statusAt : { elapsed : Duration } -> CarNumber -> StatusIndex -> Car.Status
statusAt clock carNumber (StatusIndex index) =
    Dict.get carNumber index
        |> Maybe.andThen (ChangePoints.valueAt clock.elapsed)
        |> Maybe.withDefault Car.PreRace
