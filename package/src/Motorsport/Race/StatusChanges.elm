module Motorsport.Race.StatusChanges exposing
    ( StatusChanges
    , empty, fromTimelineEvents
    , statusAt
    )

{-| Every moment a car's race begins or ends, collected once from the timeline.

A status is not something playback accumulates as the clock runs -- it is
a function of the race and the moment it is read at. This index makes that cheap:
see [`ChangePoints`](Motorsport-Internal-ChangePoints), one set of them per car.

The pit lane is not in here. A stop is counted off the laps in the first place,
and the laps are where [`Race.Snapshot`](Motorsport-Race-Snapshot) reads it back.
What the laps cannot say is where a car's race began and ended, which is what
this index is for.

@docs StatusChanges
@docs empty, fromTimelineEvents
@docs statusAt

-}

import Dict exposing (Dict)
import Motorsport.Instant exposing (Instant)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Motorsport.Status as Status exposing (Status)


{-| The change points of every car that has any, keyed by car number.

A car missing from the index -- or one whose earliest change is still ahead of the
clock -- has not taken the start yet, and reads back as `PreRace`.

-}
type StatusChanges
    = StatusChanges (Dict CarNumber (ChangePoints Status))


{-| An index over no race at all. Every car reads back as `PreRace`.
-}
empty : StatusChanges
empty =
    StatusChanges Dict.empty


{-| Build the index from a race's timeline.

Only the events that begin or end a car's race are kept. Taking the lead and the
race start itself leave the status where it was, and a stop is read off the laps
instead -- the timeline still lists both halves of one, for the race's report to
draw.

-}
fromTimelineEvents : List TimelineEvent -> StatusChanges
fromTimelineEvents events =
    events
        |> List.foldl collect Dict.empty
        |> Dict.map (\_ changes -> ChangePoints.fromList (List.reverse changes))
        |> StatusChanges


collect :
    TimelineEvent
    -> Dict CarNumber (List ( Instant, Status ))
    -> Dict CarNumber (List ( Instant, Status ))
collect { elapsed, eventType } acc =
    case statusChange eventType of
        Just ( carNumber, status ) ->
            Dict.update carNumber
                (\collected ->
                    Just (( elapsed, status ) :: Maybe.withDefault [] collected)
                )
                acc

        Nothing ->
            acc


statusChange : TimelineEvent.EventType -> Maybe ( CarNumber, Status )
statusChange eventType =
    case eventType of
        TimelineEvent.RaceStart ->
            Nothing

        TimelineEvent.CarEvent carNumber TimelineEvent.Start ->
            Just ( carNumber, Status.Racing )

        TimelineEvent.CarEvent _ (TimelineEvent.PitIn _) ->
            Nothing

        TimelineEvent.CarEvent _ (TimelineEvent.PitOut _) ->
            Nothing

        TimelineEvent.CarEvent carNumber TimelineEvent.Retirement ->
            Just ( carNumber, Status.Retired )

        TimelineEvent.CarEvent carNumber TimelineEvent.Checkered ->
            Just ( carNumber, Status.Checkered )

        TimelineEvent.CarEvent _ TimelineEvent.TookLead ->
            Nothing


{-| How far through its race a car is at a given point: `PreRace` before it
takes the start, `Racing` once it has, and `Retired` or `Checkered` once it is
over.

Never `InPit` or `OutLap`, which the laps say and this index does not carry.

-}
statusAt : { elapsed : Instant } -> CarNumber -> StatusChanges -> Status
statusAt clock carNumber (StatusChanges index) =
    Dict.get carNumber index
        |> Maybe.andThen (ChangePoints.valueAt clock.elapsed)
        |> Maybe.withDefault Status.PreRace
