module Motorsport.Race.Rivals exposing
    ( Rivals
    , around
    )

{-| The cars a car is racing: the ones drawn beside it, and the wider group they
are measured against.

@docs Rivals
@docs around

-}

import List.Extra
import Motorsport.Race.Snapshot exposing (CarAt)


{-| `display` is the car itself and the in-class rival either side of it, in
running order. `reference` is the same group widened to two rivals a side, which
only a chart baselining on the group reads, and only to average it.

Baselining on exactly the cars drawn locks a relative-gap chart into a mirror
image: the three gaps sum to zero, so the outer two lines can only move against
each other. Two more cars either side loosen that into an approximate centring
and let all three move. What such a chart is read for -- two lines converging or
diverging -- is the difference between them, which no choice of baseline
changes.

-}
type alias Rivals =
    { display : List CarAt
    , reference : List CarAt
    }


{-| The cars either side of `item` in its own class, taken from the overall
running order so the group follows the field as positions change. Filtering by
class preserves that order, so the result is the in-class order as-is.

At a class edge only the available rivals are kept, and a car the list does not
hold is its own only company.

-}
around : List CarAt -> CarAt -> Rivals
around allCars item =
    let
        classmates =
            allCars |> List.filter (\other -> other.metadata.class == item.metadata.class)

        at index =
            List.Extra.getAt index classmates
    in
    case List.Extra.findIndex (\other -> other.metadata.carNumber == item.metadata.carNumber) classmates of
        Just i ->
            let
                -- Nearest first, so the head of each is the rival on the road.
                ahead =
                    [ 1, 2 ] |> List.filterMap (\d -> at (i - d))

                behind =
                    [ 1, 2 ] |> List.filterMap (\d -> at (i + d))
            in
            { display =
                List.filterMap identity
                    [ List.head ahead, Just item, List.head behind ]
            , reference = ahead ++ item :: behind
            }

        Nothing ->
            { display = [ item ], reference = [ item ] }
