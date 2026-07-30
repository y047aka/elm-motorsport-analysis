module Motorsport.ViewModel.LapHistory exposing
    ( LapHistory
    , compute
    , get, recentLaps
    )

{-| A per-car slice of the laps completed up to the current time.

Holds raw `Lap` values but belongs to the computed-model layer in the sense that
it is already sliced by time. Only chart modules that scan lap history over time consume this.

@docs LapHistory
@docs compute
@docs get, recentLaps

-}

import Dict exposing (Dict)
import Motorsport.Duration exposing (Duration)
import Motorsport.Entrant exposing (Entrant)
import Motorsport.Lap exposing (Lap, completedLapsAt)


type LapHistory
    = LapHistory (Dict String (List Lap))


compute : { elapsed : Duration } -> List Entrant -> LapHistory
compute raceClock entrants =
    entrants
        |> List.map (\entrant -> ( entrant.metadata.carNumber, completedLapsAt raceClock entrant.laps ))
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
