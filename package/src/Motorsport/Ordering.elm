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
import Motorsport.Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import SortedList exposing (SortedList)


{-| Sort cars into the order they are running in at a moment of the race.

This carries the domain rule, which is `Lap.compareAt`'s: by lap number, then
sector, then mini-sector, then elapsed time within the current sector.

Every car handed here is driving a lap. A car that is not is not in a running
order at all -- there is no answer to where it stands -- so it is
[`Race.Snapshot`](Motorsport-Race-Snapshot)'s to leave out before it gets
here.

The result is a plain list, not a `SortedList`: the caller's next move is to
number the cars off, and it is that number `byPosition` guards.

    Ordering.runningOrder { elapsed = Instant.fromDuration 3600000 } cars
    -- The leader first, then the rest in the order they are running

-}
runningOrder : { elapsed : Instant } -> List { a | currentLap : Lap } -> List { a | currentLap : Lap }
runningOrder clock =
    List.sortWith (\a b -> Lap.compareAt clock a.currentLap b.currentLap)


{-| Phantom type marking a list as ordered by racing position.
-}
type ByPosition
    = ByPosition Never


{-| Sort by the position each item has already been given.

Takes the position rather than reading a field off the item, so that where the
caller keeps that number is the caller's business.

-}
byPosition : (a -> Int) -> List a -> SortedList ByPosition a
byPosition toPosition items =
    SortedList.sortBy (Compare.by toPosition) items
