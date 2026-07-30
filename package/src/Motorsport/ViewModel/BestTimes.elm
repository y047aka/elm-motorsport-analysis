module Motorsport.ViewModel.BestTimes exposing (BestTimes, Scope(..), compute)

{-| The fastest times within the aggregation scope (the comparison baseline).

The aggregated values a widget uses as the baseline when rating and scaling
individual times. Built by scanning every entrant's laps.

@docs BestTimes, Scope, compute

-}

import Motorsport.Circuit.LeMans exposing (ByMiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Entrant exposing (Entrant)
import Motorsport.Lap exposing (completedLapsAt)
import Motorsport.Lap.Performance exposing (calculateMiniSectorFastest, findFastest, findFastestBy, findSlowest)
import Motorsport.Sector as Sector exposing (BySector)


type alias BestTimes =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    , fastestSectors : BySector Duration
    , fastestMiniSectors : ByMiniSector Duration
    }


{-| Aggregation scope.

  - `WholeRace`: baseline over all laps (playback-position-independent, e.g. right after data load)
  - `UpToElapsed`: baseline over only the laps completed up to the clock's elapsed time (during playback)

-}
type Scope
    = WholeRace
    | UpToElapsed


compute : Scope -> { elapsed : Duration } -> List Entrant -> BestTimes
compute scope clock entrants =
    let
        lapsByCar =
            case scope of
                WholeRace ->
                    List.map .laps entrants

                UpToElapsed ->
                    List.map (.laps >> completedLapsAt clock) entrants
    in
    { fastestLapTime = lapsByCar |> findFastest |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = lapsByCar |> findSlowest |> Maybe.map .time |> Maybe.withDefault 0
    , fastestSectors =
        Sector.initialize
            (\sector ->
                lapsByCar
                    |> findFastestBy (.sectors >> Sector.get sector >> .time)
                    |> Maybe.withDefault 0
            )
    , fastestMiniSectors = calculateMiniSectorFastest lapsByCar
    }
