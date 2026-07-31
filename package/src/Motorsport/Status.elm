module Motorsport.Status exposing (Status(..), hasRetired)

{-| Where a car stands in the race: away, in the pits, out of it, done.

Needs no laps, no clock and no entry list to say it, which is why it lives on its
own: the race's record of when it changed and the badges on a timing screen both
want this and nothing more.

What a car's status actually is at a moment of the race is
[`Race.statusAt`](Motorsport-Race#statusAt).

@docs Status, hasRetired

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
