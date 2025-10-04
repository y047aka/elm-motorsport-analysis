module Motorsport.Analysis exposing (Analysis, finished, fromRaceControl)

import List.NonEmpty as NonEmpty exposing (NonEmpty)
import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (completedLapsAt)
import Motorsport.Lap.Performance exposing (LeMans2025MiniSectorFastest, calculateMiniSectorFastest, findFastest, findFastestBy, findSlowest)


type alias Analysis =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    , sector_1_fastest : Duration
    , sector_2_fastest : Duration
    , sector_3_fastest : Duration
    , miniSectorFastest : LeMans2025MiniSectorFastest
    }


fromRaceControl : { a | clock : Clock.Model, cars : NonEmpty Car } -> Analysis
fromRaceControl { clock, cars } =
    let
        raceClock =
            { elapsed = Clock.getElapsed clock }

        completedLaps =
            NonEmpty.toList cars
                |> List.map (.laps >> completedLapsAt raceClock)
    in
    { fastestLapTime = completedLaps |> findFastest |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> findSlowest |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest = completedLaps |> findFastestBy .sector_1 |> Maybe.withDefault 0
    , sector_2_fastest = completedLaps |> findFastestBy .sector_2 |> Maybe.withDefault 0
    , sector_3_fastest = completedLaps |> findFastestBy .sector_3 |> Maybe.withDefault 0
    , miniSectorFastest = calculateMiniSectorFastest completedLaps
    }


finished : { a | cars : NonEmpty Car } -> Analysis
finished { cars } =
    let
        laps =
            NonEmpty.toList cars
                |> List.map .laps
    in
    { fastestLapTime = laps |> findFastest |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = laps |> findSlowest |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest = laps |> findFastestBy .sector_1 |> Maybe.withDefault 0
    , sector_2_fastest = laps |> findFastestBy .sector_2 |> Maybe.withDefault 0
    , sector_3_fastest = laps |> findFastestBy .sector_3 |> Maybe.withDefault 0
    , miniSectorFastest = calculateMiniSectorFastest laps
    }
