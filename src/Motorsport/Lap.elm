module Motorsport.Lap exposing
    ( Lap
    , compare
    , fastestLap, slowestLap
    , completedLapsAt, findLastLapAt
    )

{-|

@docs Lap
@docs compare
@docs fastestLap, slowestLap
@docs completedLapsAt, findLastLapAt

-}

import List.Extra
import Motorsport.Clock exposing (Clock)
import Motorsport.Duration exposing (Duration)


type alias Lap =
    { carNumber : String
    , driver : String
    , lap : Int
    , time : Duration
    , best : Duration
    , elapsed : Duration
    }


compare : Lap -> Lap -> Order
compare a b =
    case Basics.compare a.lap b.lap of
        LT ->
            GT

        EQ ->
            Basics.compare a.elapsed b.elapsed

        GT ->
            LT


fastestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
fastestLap =
    List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .time)
        >> List.Extra.minimumBy .time


slowestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
slowestLap =
    List.filterMap (List.Extra.maximumBy .time)
        >> List.Extra.maximumBy .time


completedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
completedLapsAt clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)


findLastLapAt : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findLastLapAt clock =
    completedLapsAt clock >> List.Extra.last
