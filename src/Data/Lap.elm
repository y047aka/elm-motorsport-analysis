module Data.Lap exposing
    ( fastestLap, slowestLap
    , completedLapsAt, findLastLapAt
    , LapStatus(..), toLapStatus
    )

{-|

@docs fastestLap, slowestLap
@docs completedLapsAt, findLastLapAt
@docs LapStatus, toLapStatus

-}

import Data.LapTime exposing (LapTime)
import Data.RaceClock exposing (RaceClock)
import List.Extra


fastestLap : List (List { a | time : LapTime }) -> Maybe { a | time : LapTime }
fastestLap =
    List.map (List.Extra.minimumBy .time)
        >> List.filterMap identity
        >> List.Extra.minimumBy .time


slowestLap : List (List { a | time : LapTime }) -> Maybe { a | time : LapTime }
slowestLap =
    List.map (List.Extra.maximumBy .time)
        >> List.filterMap identity
        >> List.Extra.maximumBy .time


completedLapsAt : RaceClock -> List { a | elapsed : LapTime } -> List { a | elapsed : LapTime }
completedLapsAt clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)


findLastLapAt : RaceClock -> List { a | elapsed : LapTime } -> Maybe { a | elapsed : LapTime }
findLastLapAt clock =
    completedLapsAt clock >> List.Extra.last


type LapStatus
    = Fastest
    | PersonalBest
    | Normal


toLapStatus : { a | time : LapTime } -> { b | time : LapTime, fastest : LapTime } -> LapStatus
toLapStatus fastestLap_ { time, fastest } =
    if time == fastestLap_.time then
        Fastest

    else if time == fastest then
        PersonalBest

    else
        Normal
