module Motorsport.Analysis exposing (Analysis, finished, fromRaceControl)

import Dict exposing (Dict)
import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap, MiniSector(..), completedLapsAt)
import Motorsport.Lap.Performance exposing (MiniSectorFastest, calculateMiniSectorFastest, findFastest, findFastestBy, findSlowest)


type alias Analysis =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    , sector_1_fastest : Duration
    , sector_2_fastest : Duration
    , sector_3_fastest : Duration
    , miniSectorFastest : MiniSectorFastest
    }


fromRaceControl : { a | clock : Clock.Model, cars : List Car } -> Analysis
fromRaceControl { clock, cars } =
    let
        raceClock =
            { elapsed = Clock.getElapsed clock }

        completedLaps =
            List.map (.laps >> completedLapsAt raceClock) cars
    in
    { fastestLapTime = completedLaps |> findFastest |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> findSlowest |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest = completedLaps |> findFastestBy .sector_1 |> Maybe.withDefault 0
    , sector_2_fastest = completedLaps |> findFastestBy .sector_2 |> Maybe.withDefault 0
    , sector_3_fastest = completedLaps |> findFastestBy .sector_3 |> Maybe.withDefault 0
    , miniSectorFastest = calculateMiniSectorFastest completedLaps
    }


finished : { a | cars : List Car } -> Analysis
finished { cars } =
    let
        laps =
            List.map .laps cars
    in
    { fastestLapTime = laps |> findFastest |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = laps |> findSlowest |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest = laps |> findFastestBy .sector_1 |> Maybe.withDefault 0
    , sector_2_fastest = laps |> findFastestBy .sector_2 |> Maybe.withDefault 0
    , sector_3_fastest = laps |> findFastestBy .sector_3 |> Maybe.withDefault 0
    , miniSectorFastest = calculateMiniSectorFastest laps
    }
