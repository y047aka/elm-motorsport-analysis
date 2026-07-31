module Motorsport.Status exposing (Status(..), hasRetired)

{-| Where a car stands in the race: away, in the pits, out of it, done.

One of the few things said about a car that needs nothing else to say it -- no
laps, no clock, no entry list. Which is why it lives on its own: everything from
the race's own record of when it changed to the badges on a timing screen wants
this and nothing more.

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
