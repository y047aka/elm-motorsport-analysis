module Motorsport.Car.StatusIndex exposing
    ( StatusIndex
    , empty, fromTimelineEvents
    , statusAt
    )

{-| Every moment a car's status changes, collected once from the race timeline.

A status is not something the race control accumulates as the clock runs -- it is
a function of the race and the elapsed time. This index makes that function cheap:
the change points are gathered up front, and reading a status back at any elapsed
time is a binary search over them.

Because the answer depends on nothing but `elapsed`, scrubbing, jumping and
rewinding all land on the status that playing through would have reached.

@docs StatusIndex
@docs empty, fromTimelineEvents
@docs statusAt

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Motorsport.Car as Car
import Motorsport.Duration exposing (Duration)
import Motorsport.Entrant exposing (CarNumber)
import Motorsport.TimelineEvent as TimelineEvent exposing (TimelineEvent)


{-| The change points of every car that has any, keyed by car number.

A car missing from the index -- or one whose earliest change is still ahead of the
clock -- has not taken the start yet, and reads back as `PreRace`.

-}
type StatusIndex
    = StatusIndex (Dict CarNumber (Array Change))


{-| One car's status, and the elapsed time from which it holds.
-}
type alias Change =
    { at : Duration, status : Car.Status }


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
        |> List.sortBy .eventTime
        |> List.foldl collect Dict.empty
        |> Dict.map (\_ changes -> Array.fromList (List.reverse changes))
        |> StatusIndex


collect : TimelineEvent -> Dict CarNumber (List Change) -> Dict CarNumber (List Change)
collect { eventTime, eventType } acc =
    case statusChange eventType of
        Just ( carNumber, status ) ->
            Dict.update carNumber
                (\collected ->
                    Just ({ at = eventTime, status = status } :: Maybe.withDefault [] collected)
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

    StatusIndex.statusAt { elapsed = 3600000 } "7" index
    -- Racing, InPit, Retired, ...

-}
statusAt : { elapsed : Duration } -> CarNumber -> StatusIndex -> Car.Status
statusAt clock carNumber (StatusIndex index) =
    Dict.get carNumber index
        |> Maybe.andThen (lastChangeAt clock.elapsed)
        |> Maybe.map .status
        |> Maybe.withDefault Car.PreRace


{-| The last change at or before `elapsed`, or `Nothing` if the car's first change
is still ahead of the clock.

Changes sharing a timestamp keep the order the timeline listed them in, and the
last of them wins -- a car that leaves the pits and takes the flag on the same lap
ends up flagged, not racing.

-}
lastChangeAt : Duration -> Array Change -> Maybe Change
lastChangeAt elapsed changes =
    let
        -- Invariant: every change below `low` is at or before `elapsed`, and
        -- every change from `high` up is after it. The two meet at the answer.
        search low high =
            if low >= high then
                Array.get (low - 1) changes

            else
                let
                    mid =
                        low + ((high - low) // 2)
                in
                case Array.get mid changes of
                    Just change ->
                        if change.at <= elapsed then
                            search (mid + 1) high

                        else
                            search low mid

                    Nothing ->
                        Nothing
    in
    search 0 (Array.length changes)
