module Motorsport.Race.Rivals exposing
    ( Rivals
    , around
    , focused, nearest
    )

{-| The cars a car is racing, as rings around it: the rival either side is the
fight, the ones beyond them are what is coming, and wider still is a population
to measure the lot against.

How far out to look is the reader's, not this module's -- a chart drawing lines
wants fewer cars than one averaging a baseline -- so the rings come out through
[`nearest`](#nearest) rather than as named groups.

@docs Rivals
@docs around
@docs focused, nearest

-}

import List.Extra
import Motorsport.Race.Snapshot exposing (CarAt)


type Rivals
    = Rivals
        { car : CarAt
        , ahead : List CarAt
        , behind : List CarAt
        }


{-| How far out `around` gathers, in rivals a side. Past the widest ring anyone
asks for, so that asking never comes up short for a reason the caller cannot see.
-}
gathered : Int
gathered =
    4


{-| The cars either side of `item` in its own class, taken from the overall
running order so the group follows the field as positions change. Filtering by
class preserves that order, so what comes out is the in-class order as-is.

At a class edge only the available rivals are there, and a car the list does not
hold is its own only company.

-}
around : List CarAt -> CarAt -> Rivals
around allCars item =
    let
        classmates =
            allCars |> List.filter (\other -> other.metadata.class == item.metadata.class)

        side steps =
            steps |> List.filterMap (\step -> List.Extra.getAt step classmates)
    in
    case List.Extra.findIndex (\other -> other.metadata.carNumber == item.metadata.carNumber) classmates of
        Just i ->
            Rivals
                { car = item

                -- Nearest first on both sides, so `nearest` can take a ring off
                -- the front of each.
                , ahead = side (List.range 1 gathered |> List.map (\d -> i - d))
                , behind = side (List.range 1 gathered |> List.map (\d -> i + d))
                }

        Nothing ->
            Rivals { car = item, ahead = [], behind = [] }


{-| The car the group was built around, and the one a chart draws differently
from the rest.
-}
focused : Rivals -> CarAt
focused (Rivals r) =
    r.car


{-| The car and up to `count` rivals either side of it, in running order. Fewer
at a class edge, and never more than `around` gathered.
-}
nearest : Int -> Rivals -> List CarAt
nearest count (Rivals r) =
    List.reverse (List.take count r.ahead) ++ r.car :: List.take count r.behind
