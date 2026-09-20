module Motorsport.LapRange exposing
    ( LapRange
    , within
    )

{-| A stretch of the race as lap numbers, both ends drawn.

A record and not a pair, because a pair of Ints is a point on a chart in the
same call and because two Ints in a row can be swapped at a call site without a
word from the compiler.

Which laps a reader asked for is
[`Analysis.LapWindow`](Motorsport-Analysis-LapWindow)'s; this is the answer, and
what a chart's axis spans is one of these too.

@docs LapRange
@docs within

-}

import Motorsport.Lap exposing (Lap)


type alias LapRange =
    { first : Int
    , last : Int
    }


{-| One car's laps that the range covers, out of everything it has run.
-}
within : LapRange -> List Lap -> List Lap
within range =
    List.filter (\lap -> range.first <= lap.lap && lap.lap <= range.last)
