module Motorsport.ViewModel.BestTimes exposing (BestTimes, Scope(..), compute)

{-| The fastest times within the aggregation scope (the comparison baseline).

The aggregated values a widget uses as the baseline when rating and scaling
individual times. Read off the race's precomputed records; see
[`Race.Records`](Motorsport-Race-Records).

@docs BestTimes, Scope, compute

-}

import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Race exposing (Race)
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

Which one is asked for decides where the records are read: at the end of the race,
or at the clock.

-}
type Scope
    = WholeRace
    | UpToElapsed


compute : Scope -> { elapsed : Duration } -> Race -> BestTimes
compute scope clock race =
    let
        read : ChangePoints Duration -> Duration
        read points =
            (case scope of
                WholeRace ->
                    ChangePoints.last points

                UpToElapsed ->
                    ChangePoints.valueAt clock.elapsed points
            )
                -- No lap has set this time yet, or none ever records it.
                |> Maybe.withDefault 0

        records =
            race.records
    in
    { fastestLapTime = read records.fastestLapTime
    , slowestLapTime = read records.slowestLapTime
    , fastestSectors =
        Sector.initialize (\sector -> read (Sector.get sector records.fastestSectors))
    , fastestMiniSectors =
        LeMans.initialize (\mini -> read (LeMans.get mini records.fastestMiniSectors))
    }
