module Motorsport.Race.StatusChanges exposing
    ( StatusChanges
    , empty, fromTimelineEvents
    , statusAt
    )

{-| Every moment a car's status changes, collected once from the race timeline.

A status is not something playback accumulates as the clock runs -- it is
a function of the race and the moment it is read at. This index makes that cheap:
see [`ChangePoints`](Motorsport-Internal-ChangePoints), one set of them per car.

@docs StatusChanges
@docs empty, fromTimelineEvents
@docs statusAt

-}

import Dict exposing (Dict)
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
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

Only the events that move a car between statuses are kept; taking the lead and the
race start itself leave the status where it was.

The index is a reading of which events there are rather than of the order they
arrive in: two of them claiming one car at one instant are settled by
[`Status.stronger`](Motorsport-Status#stronger), which the same pair settles the
same way whichever way round they are listed.

-}
fromTimelineEvents : List TimelineEvent -> StatusChanges
fromTimelineEvents events =
    events
        |> List.foldl collect Dict.empty
        |> Dict.map (\_ changes -> ChangePoints.fromList (points changes))
        |> StatusChanges


{-| A car's changes, keyed by the moment each takes effect -- in milliseconds,
which is the whole of what an `Instant` is and the one form of it a `Dict` takes
as a key.
-}
type alias Changes =
    Dict Duration Status


collect : TimelineEvent -> Dict CarNumber Changes -> Dict CarNumber Changes
collect { elapsed, eventType } acc =
    case statusChange eventType of
        Just ( carNumber, status ) ->
            Dict.update carNumber
                (Maybe.withDefault Dict.empty
                    >> claimed (Instant.toDuration elapsed) status
                    >> Just
                )
                acc

        Nothing ->
            acc


claimed : Duration -> Status -> Changes -> Changes
claimed at status =
    Dict.update at
        (\held ->
            Just (Maybe.withDefault status held |> Status.stronger status)
        )


{-| In the order the moments happened, which is the order a `Dict` keyed by them
comes back in.
-}
points : Changes -> List ( Instant, Status )
points changes =
    changes
        |> Dict.toList
        |> List.map (Tuple.mapFirst Instant.fromDuration)


statusChange : TimelineEvent.EventType -> Maybe ( CarNumber, Status )
statusChange eventType =
    case eventType of
        TimelineEvent.RaceStart ->
            Nothing

        TimelineEvent.CarEvent carNumber TimelineEvent.Start ->
            Just ( carNumber, Status.Racing )

        TimelineEvent.CarEvent carNumber (TimelineEvent.PitIn _) ->
            Just ( carNumber, Status.InPit )

        TimelineEvent.CarEvent carNumber (TimelineEvent.PitOut _) ->
            Just ( carNumber, Status.Racing )

        TimelineEvent.CarEvent carNumber TimelineEvent.Retirement ->
            Just ( carNumber, Status.Retired )

        TimelineEvent.CarEvent carNumber TimelineEvent.Checkered ->
            Just ( carNumber, Status.Checkered )

        TimelineEvent.CarEvent _ TimelineEvent.TookLead ->
            Nothing


{-| The status a car holds at a given point in the race.

Where a pit exit and the chequered flag land on the same instant the flag wins,
being the stronger of the two -- see
[`Status.stronger`](Motorsport-Status#stronger).

    StatusChanges.statusAt { elapsed = Instant.fromDuration 3600000 } "7" index
    -- Racing, InPit, Retired, ...

-}
statusAt : { elapsed : Instant } -> CarNumber -> StatusChanges -> Status
statusAt clock carNumber (StatusChanges index) =
    Dict.get carNumber index
        |> Maybe.andThen (ChangePoints.valueAt clock.elapsed)
        |> Maybe.withDefault Status.PreRace
