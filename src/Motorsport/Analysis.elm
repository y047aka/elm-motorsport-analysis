module Motorsport.Analysis exposing (Analysis, finished, fromRaceControl)

import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Clock exposing (Clock)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (completedLapsAt, fastestLap, slowestLap)


type alias Analysis =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    , sector_1_fastest : Duration
    , sector_2_fastest : Duration
    , sector_3_fastest : Duration
    }


fromRaceControl : { a | raceClock : Clock, cars : List Car } -> Analysis
fromRaceControl { raceClock, cars } =
    let
        completedLaps =
            List.map (.laps >> completedLapsAt raceClock) cars
    in
    { fastestLapTime = completedLaps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest =
        completedLaps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_1)
            |> List.Extra.minimumBy .sector_1
            |> Maybe.map .sector_1
            |> Maybe.withDefault 0
    , sector_2_fastest =
        completedLaps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_2)
            |> List.Extra.minimumBy .sector_2
            |> Maybe.map .sector_2
            |> Maybe.withDefault 0
    , sector_3_fastest =
        completedLaps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_3)
            |> List.Extra.minimumBy .sector_3
            |> Maybe.map .sector_3
            |> Maybe.withDefault 0
    }


finished : { a | cars : List Car } -> Analysis
finished { cars } =
    let
        laps =
            List.map .laps cars
    in
    { fastestLapTime = laps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = laps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest =
        laps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_1)
            |> List.Extra.minimumBy .sector_1
            |> Maybe.map .sector_1
            |> Maybe.withDefault 0
    , sector_2_fastest =
        laps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_2)
            |> List.Extra.minimumBy .sector_2
            |> Maybe.map .sector_2
            |> Maybe.withDefault 0
    , sector_3_fastest =
        laps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_3)
            |> List.Extra.minimumBy .sector_3
            |> Maybe.map .sector_3
            |> Maybe.withDefault 0
    }
