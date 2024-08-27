module Motorsport.Analysis exposing (Analysis, finished, fromRaceControl)

import Motorsport.Car exposing (Car)
import Motorsport.Clock exposing (Clock)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (completedLapsAt, fastestLap, slowestLap)


type alias Analysis =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    }


fromRaceControl : { a | raceClock : Clock, cars : List Car } -> Analysis
fromRaceControl { raceClock, cars } =
    let
        completedLaps =
            List.map (.laps >> completedLapsAt raceClock) cars
    in
    { fastestLapTime = completedLaps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    }


finished : { a | raceClock : Clock, cars : List Car } -> Analysis
finished { cars } =
    let
        laps =
            List.map .laps cars
    in
    { fastestLapTime = laps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = laps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    }
