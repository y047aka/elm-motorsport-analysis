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

Only the events that move a car between statuses are kept; taking the lead and the
race start itself leave the status where it was.

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


statusChange : TimelineEvent.EventType -> Maybe ( CarNumber, Status )
statusChange eventType =
    case eventType of
        TimelineEvent.RaceStart ->
            Nothing

        TimelineEvent.CarEvent carNumber (TimelineEvent.Start _) ->
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
because the timeline lists it later -- see
[`ChangePoints.fromList`](Motorsport-Internal-ChangePoints#fromList).

    StatusChanges.statusAt { elapsed = Instant.fromDuration 3600000 } "7" index
    -- Racing, InPit, Retired, ...

-}
statusAt : { elapsed : Instant } -> CarNumber -> StatusChanges -> Status
statusAt clock carNumber (StatusChanges index) =
    Dict.get carNumber index
        |> Maybe.andThen (ChangePoints.valueAt clock.elapsed)
        |> Maybe.withDefault Status.PreRace
