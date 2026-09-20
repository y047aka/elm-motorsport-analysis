module Motorsport.Analysis.Rivals exposing
    ( Rivals
    , around
    , focused, class
    , fight, nearest
    )

{-| The cars a car is racing, as rings around it: the rival either side is the
fight, the ones beyond them are what is coming, and wider still is a population
to measure the lot against.

The fight -- the car and the rival either side -- is named here, being the ring
every view comparing cars draws. The wider rings are the reader's and come out
through [`nearest`](#nearest): a chart drawing lines wants fewer cars than one
averaging a baseline.

@docs Rivals
@docs around
@docs focused, class
@docs fight, nearest

-}

import List.Extra
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Wec.Class exposing (Class)


type Rivals
    = Rivals
        { car : CarAt
        , ahead : List CarAt
        , behind : List CarAt
        }


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
    in
    case List.Extra.findIndex (\other -> other.metadata.carNumber == item.metadata.carNumber) classmates of
        Just i ->
            Rivals
                { car = item

                -- The whole class either side, nearest first on both, so that
                -- `nearest` takes a ring off the front of each and no ring a
                -- caller asks for is quietly cut short.
                , ahead = classmates |> List.take i |> List.reverse
                , behind = classmates |> List.drop (i + 1)
                }

        Nothing ->
            Rivals { car = item, ahead = [], behind = [] }


{-| The car the group was built around, and the one a chart draws differently
from the rest.
-}
focused : Rivals -> CarAt
focused (Rivals r) =
    r.car


{-| The class the group was taken from, which is the one `around` filtered the
field by.
-}
class : Rivals -> Class
class (Rivals r) =
    r.car.metadata.class


{-| The car and the rival either side of it: the cars a view compares, and the
ones a legend beside it names.
-}
fight : Rivals -> List CarAt
fight =
    nearest 1


{-| The car and up to `count` rivals either side of it, in running order. Fewer
where the class runs out, which at its edges is all of one side.
-}
nearest : Int -> Rivals -> List CarAt
nearest count (Rivals r) =
    List.reverse (List.take count r.ahead) ++ r.car :: List.take count r.behind
