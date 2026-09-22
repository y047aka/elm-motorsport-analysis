module Motorsport.Analysis.Entrant exposing (cars)

{-| An entrant is a team in one class, and the cars it enters there are one
another's teammates.

The team's name alone does not say who those are: United Autosports ran two
cars in LMP2 at Le Mans in 2025 and two more in LMGT3, and the LMP2 pair are
racing nobody the LMGT3 pair are racing.

@docs cars

-}

import Motorsport.Race.Snapshot exposing (CarAt)


{-| The cars of `item`'s entrant, taken from the overall running order so they
come out in the order the race has them, `item` among them.

A car the list does not hold is its own only company.

-}
cars : List CarAt -> CarAt -> List CarAt
cars allCars item =
    let
        sameEntrant other =
            (other.metadata.team == item.metadata.team)
                && (other.metadata.class == item.metadata.class)

        entered =
            List.filter sameEntrant allCars
    in
    -- The filter can find the entrant's other cars without finding `item`,
    -- and teammates without the car is not what a caller means by its entrant.
    if List.any (\other -> other.metadata.carNumber == item.metadata.carNumber) entered then
        entered

    else
        [ item ]
