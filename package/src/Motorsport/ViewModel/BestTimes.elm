module Motorsport.ViewModel.BestTimes exposing (BestTimes, Scope(..), compute)

{-| The fastest times within the aggregation scope (the comparison baseline).

The aggregated values a widget uses as the baseline when rating and scaling
individual times. Built by scanning the domain model (RunningOrder).

@docs BestTimes, Scope, compute

-}

import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (completedLapsAt)
import Motorsport.Lap.Performance exposing (LeMans2025MiniSectorFastest, calculateMiniSectorFastest, findFastest, findFastestBy, findSlowest)
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)


type alias BestTimes =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    , fastestSector_1 : Duration
    , fastestSector_2 : Duration
    , fastestSector_3 : Duration
    , fastestMiniSectors : LeMans2025MiniSectorFastest
    }


{-| Aggregation scope.

  - `WholeRace`: baseline over all laps (playback-position-independent, e.g. right after data load)
  - `UpToElapsed`: baseline over only the laps completed up to the clock's elapsed time (during playback)

-}
type Scope
    = WholeRace
    | UpToElapsed


compute : Scope -> { a | clock : Clock.Model, cars : RunningOrder } -> BestTimes
compute scope { clock, cars } =
    let
        lapsByCar =
            case scope of
                WholeRace ->
                    RunningOrder.toList cars
                        |> List.map .laps

                UpToElapsed ->
                    let
                        raceClock =
                            { elapsed = Clock.getElapsed clock }
                    in
                    RunningOrder.toList cars
                        |> List.map (.laps >> completedLapsAt raceClock)
    in
    { fastestLapTime = lapsByCar |> findFastest |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = lapsByCar |> findSlowest |> Maybe.map .time |> Maybe.withDefault 0
    , fastestSector_1 = lapsByCar |> findFastestBy .sector_1 |> Maybe.withDefault 0
    , fastestSector_2 = lapsByCar |> findFastestBy .sector_2 |> Maybe.withDefault 0
    , fastestSector_3 = lapsByCar |> findFastestBy .sector_3 |> Maybe.withDefault 0
    , fastestMiniSectors = calculateMiniSectorFastest lapsByCar
    }
