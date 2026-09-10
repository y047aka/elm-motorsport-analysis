module Motorsport.Status exposing (Status(..), hasRetired, stronger)

{-| Where a car stands in the race: away, in the pits, out of it, done.

Needs no laps, no clock and no entry list to say it, which is why it lives on its
own: the race's record of when it changed and the badges on a timing screen both
want this and nothing more.

What a car's status actually is at a moment of the race is
[`Race.statusAt`](Motorsport-Race#statusAt).

@docs Status, hasRetired, stronger

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


{-| Which of two statuses a car holds where the race claims both of them at one
instant.

A car whose race has ended is not in the pits or out of them, however the
moment's other event reads: a stop ending as the flag falls leaves the car
classified rather than running. Read as an order over the whole type, that is
each status ranked by how little is left to happen to the car.

    stronger Racing Checkered
    --> Checkered

    stronger Retired Racing
    --> Retired

-}
stronger : Status -> Status -> Status
stronger a b =
    if rank b > rank a then
        b

    else
        a


rank : Status -> Int
rank status =
    case status of
        PreRace ->
            0

        Racing ->
            1

        InPit ->
            2

        Checkered ->
            3

        Retired ->
            4
