module Data.Lap exposing
    ( fastestLap, slowestLap
    , completedLapsAt, findLastLapAt
    , LapStatus(..), lapStatus
    )

{-|

@docs fastestLap, slowestLap
@docs completedLapsAt, findLastLapAt
@docs LapStatus, lapStatus

-}

import Data.Duration exposing (Duration)
import Data.RaceClock exposing (RaceClock)
import List.Extra


fastestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
fastestLap =
    List.map (List.Extra.minimumBy .time)
        >> List.filterMap identity
        >> List.Extra.minimumBy .time


slowestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
slowestLap =
    List.map (List.Extra.maximumBy .time)
        >> List.filterMap identity
        >> List.Extra.maximumBy .time


completedLapsAt : RaceClock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
completedLapsAt clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)


findLastLapAt : RaceClock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
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
