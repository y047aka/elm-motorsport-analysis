module Motorsport.Lap.Performance exposing
    ( RatedTime, rate, rateTime
    , SectorPerformance, ofSectors
    , MiniSectorPerformance, ofMiniSectors
    , PerformanceLevel(..), performanceLevel
    , isStandard
    , toColorVariable
    )

{-| How a lap's times read against the baselines they are rated on.

The baselines come from [`BestTimes`](Motorsport-BestTimes); this module says
what a time rated against them is, and rates the times of a lap one by one.

Rating belongs to neither the race nor the view. A rated time is settled by the
lap and the record alone, so [`Race.Snapshot`](Motorsport-Race-Snapshot) reads it
as part of the race; but nothing in the race changes when it is read, so the view
is free to rate a lap of its own.

@docs RatedTime, rate, rateTime
@docs SectorPerformance, ofSectors
@docs MiniSectorPerformance, ofMiniSectors

@docs PerformanceLevel, performanceLevel
@docs isStandard
@docs toColorVariable

-}

import Motorsport.BestTimes as BestTimes
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Sector as Sector exposing (BySector)


type alias RatedTime =
    { time : Duration
    , performance : PerformanceLevel
    }


{-| Rate a time against the race's record and the car's own.

For a time that is certainly there -- a running lap's elapsed time is read off
the clock, so there is always one. A time out of the source data may not have
been recorded, and takes [`rateTime`](#rateTime) instead.

-}
rate : Maybe Duration -> { time : Duration, personalBest : Maybe Duration } -> RatedTime
rate fastest { time, personalBest } =
    { time = time
    , performance =
        performanceLevel { time = time, personalBest = personalBest, fastest = fastest }
    }


{-| Rate a time where there is a time to rate. A time the source data did not
record produces no rating rather than an uncoloured one, so a caller renders the
same "-" it renders for a car with no lap at all.
-}
rateTime : Maybe Duration -> { time : Maybe Duration, personalBest : Maybe Duration } -> Maybe RatedTime
rateTime fastest { time, personalBest } =
    time
        |> Maybe.map
            (\recordedTime -> rate fastest { time = recordedTime, personalBest = personalBest })


{-| A lap's sector times, each rated.
-}
type alias SectorPerformance =
    BySector (Maybe RatedTime)


{-| Rate each sector of a lap.

A `SectorTime` is already the shape [`rateTime`](#rateTime) reads: a time that
may not have been recorded, and the driver's best to rate it against.

-}
ofSectors : BestTimes.Snapshot -> Lap -> SectorPerformance
ofSectors bestTimes lap =
    Sector.map2 (BestTimes.timeOf >> rateTime) bestTimes.fastestSectors lap.sectors


{-| A lap's mini-sector times, each rated. Only laps from a circuit with
mini-sectors have them.
-}
type alias MiniSectorPerformance =
    ByMiniSector (Maybe RatedTime)


{-| Rate each mini-sector of a lap, where the lap has any.
-}
ofMiniSectors : BestTimes.Snapshot -> Lap -> Maybe MiniSectorPerformance
ofMiniSectors bestTimes lap =
    let
        rate miniSector fastest =
            rateTime (BestTimes.timeOf fastest)
                { time = miniSector.time, personalBest = miniSector.best }
    in
    lap.miniSectors
        |> Maybe.map (\ms -> LeMans.map2 rate ms bestTimes.fastestMiniSectors)



-- PerformanceLevel


type PerformanceLevel
    = Fastest
    | PersonalBest
    | Standard


{-| How a time reads against the two baselines it is rated on.

Both baselines are `Nothing` until some lap sets them, and nothing has beaten a
record that has not been set -- so an unset baseline matches no time, and the
comparison needs no guard of its own. There is only a time to rate here at all
because the loader dropped the ones the source data did not record, on the way
in -- see [`Lap.recorded`](Motorsport-Lap#recorded).

-}
performanceLevel : { a | time : Duration, personalBest : Maybe Duration, fastest : Maybe Duration } -> PerformanceLevel
performanceLevel { time, personalBest, fastest } =
    if fastest == Just time then
        Fastest

    else if personalBest == Just time then
        PersonalBest

    else
        Standard


isStandard : PerformanceLevel -> Bool
isStandard level =
    level == Standard


toColorVariable : PerformanceLevel -> String
toColorVariable level =
    case level of
        Fastest ->
            "var(--performance-fastest)"

        PersonalBest ->
            "var(--performance-personal-best)"

        Standard ->
            "var(--performance-standard)"
