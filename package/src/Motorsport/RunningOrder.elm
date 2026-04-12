module Motorsport.RunningOrder exposing (RunningOrder, fromList, singleton, leader, toList)

{-| A running order represents a non-empty, race-position-sorted list of cars.

The race position ordering is determined by lap progress, sector advancement, and elapsed time.
This type guarantees that cars are always sorted by the current race position at the moment of
construction, and records the clock time at which the ordering was computed.

@docs RunningOrder
@docs fromList, singleton
@docs leader, toList

-}

import Motorsport.Car exposing (Car)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap


{-| A non-empty list of cars sorted by race position, computed at a specific clock time.

The invariant that cars are sorted by race position is maintained at construction time.
The first field records the elapsed time at which the ordering was computed.
The second field guarantees at least one car exists (non-empty by construction).

Use `validAt` to check whether the ordering is still current.

-}
type RunningOrder
    = RunningOrder Duration Car (List Car)


{-| Create a running order with cars sorted by their current race position.

Returns `Nothing` if the input list is empty.

    RunningOrder.fromList { elapsed = 3600000 } cars
    -- Just (Cars sorted by: lap number → sector → mini-sector → elapsed in sector)

    RunningOrder.fromList { elapsed = 0 } []
    -- Nothing

-}
fromList : { elapsed : Duration } -> List Car -> Maybe RunningOrder
fromList clock cars =
    case List.sortWith (compareByRacePosition clock) cars of
        first :: rest ->
            Just (RunningOrder clock.elapsed first rest)

        [] ->
            Nothing


{-| Create a running order with a single car at a given clock time.

Useful for initialization or placeholder values.

-}
singleton : { elapsed : Duration } -> Car -> RunningOrder
singleton clock car =
    RunningOrder clock.elapsed car []


{-| Get the leader (first car in the running order).

    RunningOrder.leader runningOrder
    -- Returns the car in 1st position

-}
leader : RunningOrder -> Car
leader (RunningOrder _ first _) =
    first


{-| Convert running order to a list of cars, preserving the race position order.

Always returns a non-empty list. Use this result with `fromList` after transformations.

    RunningOrder.toList runningOrder
    -- Returns cars ordered by position: 1st, 2nd, 3rd, ...

-}
toList : RunningOrder -> List Car
toList (RunningOrder _ first rest) =
    first :: rest


{-| Compare two cars by their race position.

This encapsulates the domain rule: cars with current lap information are ahead of
cars without it. Among cars with lap info, the comparison uses Lap.compareAt which
considers lap number, sector, mini-sector, and elapsed time within current sector.

-}
compareByRacePosition : { elapsed : Duration } -> Car -> Car -> Order
compareByRacePosition clock a b =
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
