module Motorsport.ChangePoints exposing
    ( ChangePoints
    , empty, fromList
    , valueAt, countUpTo, timeOf, length
    )

{-| A value that changes at known moments of the race, indexed so it can be read
back at any elapsed time.

The race's own shape is what makes this worth building. A car's status changes a
few dozen times across a twenty-thousand-lap race; a lap record a few hundred.
Collect the moments it changes once, when the race loads, and reading the value
at an elapsed time becomes a binary search rather than a scan of every lap.

The reading depends on nothing but `elapsed`, so a clock that jumped an hour or
scrubbed backwards lands on the same value as one that played through.

@docs ChangePoints
@docs empty, fromList
@docs valueAt, countUpTo, timeOf, length

-}

import Array exposing (Array)
import Motorsport.Duration exposing (Duration)


type ChangePoints a
    = ChangePoints (Array ( Duration, a ))


{-| No changes at all. Every reading comes back `Nothing`.
-}
empty : ChangePoints a
empty =
    ChangePoints Array.empty


{-| Index a list of changes, each paired with the elapsed time it takes effect.

The list is sorted by time, stably, so changes sharing a moment keep the order
they were given in -- and `valueAt` takes the last of them. That is what lets an
index built from an event list agree with folding over the same list.

-}
fromList : List ( Duration, a ) -> ChangePoints a
fromList changes =
    ChangePoints (Array.fromList (List.sortBy Tuple.first changes))


{-| The value in force at `elapsed`: the last change at or before it, or
`Nothing` while the first change is still ahead of the clock.
-}
valueAt : Duration -> ChangePoints a -> Maybe a
valueAt elapsed ((ChangePoints points) as index) =
    Array.get (countUpTo elapsed index - 1) points
        |> Maybe.map Tuple.second


{-| How many changes have happened by `elapsed`.
-}
countUpTo : Duration -> ChangePoints a -> Int
countUpTo elapsed (ChangePoints points) =
    search elapsed points 0 (Array.length points)


{-| When the `n`th change happened, counting from zero.
-}
timeOf : Int -> ChangePoints a -> Maybe Duration
timeOf n (ChangePoints points) =
    Array.get n points
        |> Maybe.map Tuple.first


{-| How many changes there are in all.
-}
length : ChangePoints a -> Int
length (ChangePoints points) =
    Array.length points


{-| Invariant: every change below `low` is at or before `elapsed`, and every
change from `high` up is after it. The two meet at the count.
-}
search : Duration -> Array ( Duration, a ) -> Int -> Int -> Int
search elapsed points low high =
    if low >= high then
        low

    else
        let
            mid =
                low + ((high - low) // 2)
        in
        case Array.get mid points of
            Just ( at, _ ) ->
                if at <= elapsed then
                    search elapsed points (mid + 1) high

                else
                    search elapsed points low mid

            Nothing ->
                low
