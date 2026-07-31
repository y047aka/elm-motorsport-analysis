module Motorsport.Ordering exposing
    ( runningOrder
    , ByPosition, byPosition
    )

{-| Motorsport-specific ordering.

Two different things get called a position. `runningOrder` works out who is
actually ahead on track at a moment of the race. `byPosition` sorts by the number
that ordering has already handed out, and returns a phantom-typed `SortedList` so
the two cannot be mixed up downstream.


# On track

@docs runningOrder


# Position Ordering

@docs ByPosition, byPosition

-}

import Compare
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import SortedList exposing (SortedList)


{-| Sort cars into the order they are running in at a moment of the race.

This carries the domain rule: a car with a lap in progress is ahead of one
without, and between two cars that are both running, `Lap.compareAt` decides --
by lap number, then sector, then mini-sector, then elapsed time within the
current sector.

The result is a plain list, not a `SortedList`: the caller's next move is to
number the cars off, and it is that number `byPosition` guards.

    Ordering.runningOrder { elapsed = 3600000 } cars
    -- The leader first, then the rest in the order they are running

-}
runningOrder : { elapsed : Duration } -> List { a | currentLap : Maybe Lap } -> List { a | currentLap : Maybe Lap }
runningOrder clock =
    List.sortWith (compareOnTrack clock)


compareOnTrack :
    { elapsed : Duration }
    -> { a | currentLap : Maybe Lap }
    -> { a | currentLap : Maybe Lap }
    -> Order
compareOnTrack clock a b =
    case ( a.currentLap, b.currentLap ) of
        ( Just lapA, Just lapB ) ->
            Lap.compareAt clock lapA lapB

        ( Just _, Nothing ) ->
            LT

        ( Nothing, Just _ ) ->
            GT

        ( Nothing, Nothing ) ->
            -- Ordering between two cars without lap data is undefined.
            -- List.sortWith is stable, so their relative order from the input list is preserved.
            EQ


{-| Phantom type marking a list as ordered by racing position.
-}
type ByPosition
    = ByPosition Never


{-| Sort by the position each item has already been given.
-}
byPosition : List { a | position : Int } -> SortedList ByPosition { a | position : Int }
byPosition items =
    SortedList.sortBy (Compare.by .position) items
