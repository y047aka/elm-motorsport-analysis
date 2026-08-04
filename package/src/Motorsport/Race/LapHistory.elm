module Motorsport.Race.LapHistory exposing
    ( LapHistory
    , at
    , get, recentLaps
    )

{-| Each car's laps, cut off at a moment of the race.

The laps come out exactly as they went in; the only thing applied to them is the
clock. What reads this is whatever scans a car's history rather than its present
-- the gap and distribution charts, the sparklines -- and
[`Race.Snapshot`](Motorsport-Race-Snapshot) takes one at its own clock so they
all read the same laps.

@docs LapHistory
@docs at
@docs get, recentLaps

-}

import Dict exposing (Dict)
import Motorsport.Instant exposing (Instant)
import Motorsport.Lap exposing (Lap, completedLapsAt)
import Motorsport.Race.Car exposing (Car)


type LapHistory
    = LapHistory (Dict String (List Lap))


{-| Every lap each car had completed at a moment of the race.
-}
at : { elapsed : Instant } -> List Car -> LapHistory
at clock cars =
    cars
        |> List.map (\car -> ( car.metadata.carNumber, completedLapsAt clock car.laps ))
        |> Dict.fromList
        |> LapHistory


{-| Get the lap history for a carNumber.
-}
get : String -> LapHistory -> List Lap
get carNumber (LapHistory histories) =
    Dict.get carNumber histories
        |> Maybe.withDefault []


recentLaps : { count : Int, currentLap : Int } -> List Lap -> List Lap
recentLaps { count, currentLap } lapList =
    let
        targetRange =
            List.range (currentLap - count) currentLap
    in
    lapList
        |> List.filter (\lap -> List.member lap.lap targetRange)
        |> List.sortBy .lap
