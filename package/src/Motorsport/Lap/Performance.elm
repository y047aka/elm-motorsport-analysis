module Motorsport.Lap.Performance exposing
    ( RatedTime, rateTime
    , SectorPerformance, ofSectors
    , MiniSectorPerformance, ofMiniSectors
    , SegmentState(..), fromProgress, ratedOf
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

@docs RatedTime, rateTime
@docs SectorPerformance, ofSectors
@docs MiniSectorPerformance, ofMiniSectors


## How far the car has got through a segment

@docs SegmentState, fromProgress, ratedOf

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


{-| Rate a time against the race's record and the car's own, where there is a
time to rate. A time the source data did not record produces no rating rather
than an uncoloured one, so a caller renders the same "-" it renders for a car
with no lap at all.

A time that is certainly there -- a running lap's, read off the clock -- wants
[`performanceLevel`](#performanceLevel) instead, and keeps the time under
whatever name it already has.

-}
rateTime : Maybe Duration -> { time : Maybe Duration, personalBest : Maybe Duration } -> Maybe RatedTime
rateTime fastest { time, personalBest } =
    time
        |> Maybe.map
            (\recordedTime ->
                { time = recordedTime
                , performance =
                    performanceLevel
                        { time = recordedTime, personalBest = personalBest, fastest = fastest }
                }
            )


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
        -- A `MiniSectorTime` carries the two `rateTime` reads under the names it
        -- reads them by, and one more it does not; naming them again here is
        -- what leaves that one behind.
        rateOne miniSector fastest =
            rateTime (BestTimes.timeOf fastest)
                { time = miniSector.time, personalBest = miniSector.personalBest }
    in
    lap.miniSectors
        |> Maybe.map (\ms -> LeMans.map2 rateOne ms bestTimes.fastestMiniSectors)



-- HOW FAR THE CAR HAS GOT THROUGH A SEGMENT


{-| One segment of the lap a car is on -- a sector or a mini-sector -- as it
reads at a moment of the race: the car has not reached it, is somewhere inside
it, or has the whole of it behind. Both grains read the same way, which is why
the type is not spelled twice.

Only `Completed` carries a rating, and that is the point of the type rather than
a detail of it. The race data holds every sector time of a lap from the start,
the ones the car has not driven yet included, so a shape that paired a rating
with a progress would hand a view the time a car is _going_ to set.

Its `Maybe` is the other absence: a segment the source data has no time for
finishes with nothing to rate, and a view paints it the standard colour. It is
the `Nothing` [`rateTime`](#rateTime) produces, kept in the one state where a
time was due.

-}
type SegmentState
    = NotEntered
    | InProgress Float
    | Completed (Maybe RatedTime)


{-| The state of the segment the car is currently inside, from how far through
it the clock puts them.

A progress of 1 is a segment behind the car, not one it is still in: callers
clamp progress to at most 1, so a clock past the end of the lap reads as exactly
1 of the final segment. Routing that to `Completed` here saves every caller from
having to know that 1 is a boundary.

    fromProgress 0.5 Nothing
    --> InProgress 0.5

    fromProgress 1 Nothing
    --> Completed Nothing

-}
fromProgress : Float -> Maybe RatedTime -> SegmentState
fromProgress progress rated =
    if progress >= 1 then
        Completed rated

    else
        InProgress progress


{-| The rating of a segment the car has finished, where it has finished one and
the source data timed it.

    ratedOf NotEntered
    --> Nothing

-}
ratedOf : SegmentState -> Maybe RatedTime
ratedOf state =
    case state of
        Completed rated ->
            rated

        InProgress _ ->
            Nothing

        NotEntered ->
            Nothing



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
