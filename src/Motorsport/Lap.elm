module Motorsport.Lap exposing
    ( Lap, empty
    , compareAt
    , personalBestLap, fastestLap, slowestLap
    , completedLapsAt, findLastLapAt, findCurrentLap
    , Sector(..)
    , currentSector
    )

{-|

@docs Lap, empty
@docs compareAt
@docs personalBestLap, fastestLap, slowestLap
@docs completedLapsAt, findLastLapAt, findCurrentLap

@docs Sector
@docs currentSector

-}

import List.Extra
import Motorsport.Duration exposing (Duration)


type alias Lap =
    { carNumber : String
    , driver : String
    , lap : Int
    , position : Maybe Int
    , time : Duration
    , best : Duration
    , sector_1 : Duration
    , sector_2 : Duration
    , sector_3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    , elapsed : Duration
    }


empty : Lap
empty =
    { carNumber = ""
    , driver = ""
    , lap = 0
    , position = Nothing
    , time = 0
    , sector_1 = 0
    , sector_2 = 0
    , sector_3 = 0
    , s1_best = 0
    , s2_best = 0
    , s3_best = 0
    , best = 0
    , elapsed = 0
    }


type alias Clock =
    { elapsed : Duration }


compareAt : Clock -> Lap -> Lap -> Order
compareAt clock a b =
    case Basics.compare a.lap b.lap of
        LT ->
            GT

        EQ ->
            let
                currentSector_a =
                    currentSector clock a

                currentSector_b =
                    currentSector clock b
            in
            case Basics.compare (sectorToString currentSector_a) (sectorToString currentSector_b) of
                LT ->
                    GT

                EQ ->
                    Basics.compare (sectorToElapsed a currentSector_a) (sectorToElapsed b currentSector_b)

                GT ->
                    LT

        GT ->
            LT


personalBestLap : List { a | time : Duration } -> Maybe { a | time : Duration }
personalBestLap =
    List.filter (.time >> (/=) 0)
        >> List.Extra.minimumBy .time


fastestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
fastestLap =
    List.filterMap personalBestLap
        >> List.Extra.minimumBy .time


slowestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
slowestLap =
    List.filterMap (List.Extra.maximumBy .time)
        >> List.Extra.maximumBy .time


completedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
completedLapsAt clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)


imcompletedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
imcompletedLapsAt clock laps =
    let
        incompletedLaps =
            List.filter (\lap -> lap.elapsed > clock.elapsed) laps
    in
    case incompletedLaps of
        [] ->
            List.filterMap identity [ List.Extra.last laps ]

        _ ->
            incompletedLaps


findLastLapAt : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findLastLapAt clock =
    completedLapsAt clock >> List.Extra.last


findCurrentLap : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findCurrentLap clock =
    imcompletedLapsAt clock >> List.head



-- SECTOR


type Sector
    = S1
    | S2
    | S3


currentSector : Clock -> Lap -> Sector
currentSector clock lap =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    if clock.elapsed >= elapsed_lastLap && clock.elapsed < (elapsed_lastLap + lap.sector_1) then
        S1

    else if clock.elapsed >= (elapsed_lastLap + lap.sector_1) && clock.elapsed < (elapsed_lastLap + lap.sector_1 + lap.sector_2) then
        S2

    else
        S3


sectorToString : Sector -> String
sectorToString sector =
    case sector of
        S1 ->
            "S1"

        S2 ->
            "S2"

        S3 ->
            "S3"


sectorToElapsed : Lap -> Sector -> Duration
sectorToElapsed lap sector =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    case sector of
        S1 ->
            elapsed_lastLap

        S2 ->
            elapsed_lastLap + lap.sector_1

        S3 ->
            elapsed_lastLap + lap.sector_1 + lap.sector_2
