module Motorsport.Lap exposing
    ( Lap
    , maxLapCount, fastestLap, slowestLap
    , completedLapsAt, findLastLapAt
    , LapStatus(..), lapStatus
    )

{-|

@docs Lap
@docs maxLapCount, fastestLap, slowestLap
@docs completedLapsAt, findLastLapAt
@docs LapStatus, lapStatus

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


maxLapCount : List (List Lap) -> Int
maxLapCount =
    List.map List.length
        >> List.maximum
        >> Maybe.withDefault 0


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


type LapStatus
    = Fastest
    | PersonalBest
    | Normal


lapStatus : { a | time : Duration } -> { b | time : Duration, best : Duration } -> LapStatus
lapStatus fastestLap_ { time, best } =
    if time == fastestLap_.time then
        Fastest

    else if time == best then
        PersonalBest

    else
        Normal
