module Motorsport.Status exposing (Status(..), hasRetired, hasStopped)

{-| Where a car stands in the race: away, in the pits, out of it, done.

Needs no laps, no clock and no entry list to say it, which is why it lives on its
own: the race's record of when it changed and the badges on a timing screen both
want this and nothing more.

What a car's status actually is at a moment of the race is
[`Race.statusAt`](Motorsport-Race#statusAt).

@docs Status, hasRetired, hasStopped

-}


type Status
    = PreRace
    | Racing
    | InPit
    | Checkered
    | Retired


hasRetired : Status -> Bool
hasRetired =
    (==) Retired


{-| Whether the car is done for the day, one way or the other.

A car that has retired or taken the flag has no lap under way, and
[`Race.Snapshot`](Motorsport-Race-Snapshot) keeps the last lap it ran as its
current one -- so a reading of "the lap the car is on" is a reading of a lap
that has already been shown as the last.

    hasStopped Checkered
    --> True

    hasStopped InPit
    --> False

-}
hasStopped : Status -> Bool
hasStopped status =
    case status of
        Retired ->
            True

        Checkered ->
            True

        _ ->
            False
