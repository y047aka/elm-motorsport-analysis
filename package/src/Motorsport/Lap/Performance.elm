module Motorsport.Lap.Performance exposing
    ( RatedTime, rateTime
    , SectorPerformance, ofSectors
    , MiniSectorPerformance, ofMiniSectors
    , SegmentState(..), fromProgress, ratedOf
    , PerformanceLevel(..), performanceLevel
    , isStandard
    , toColorVariable, colorOf, textColorOf, inProgressColor
    )

{-| How a lap's times read against the baselines they are rated on.

The baselines come from [`BestTimes`](Motorsport-BestTimes); this module says
what a time rated against them is, and rates the times of a lap one by one.

@docs RatedTime, rateTime
@docs SectorPerformance, ofSectors
@docs MiniSectorPerformance, ofMiniSectors


## How far the car has got through a segment

@docs SegmentState, fromProgress, ratedOf

@docs PerformanceLevel, performanceLevel
@docs isStandard
@docs toColorVariable, colorOf, textColorOf, inProgressColor

-}

import Motorsport.BestTimes as BestTimes
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)


type alias RatedTime =
    { time : Duration
    , performance : PerformanceLevel
    }


{-| Rate a time against the race's record and the car's own, where there is a
time to rate. A time the source data did not record produces no rating rather
than an uncoloured one.

A time that is certainly there -- a running lap's, read off the clock -- wants
[`performanceLevel`](#performanceLevel) instead.

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


type alias SectorPerformance =
    BySector (Maybe RatedTime)


ofSectors : BestTimes.Snapshot -> Lap -> SectorPerformance
ofSectors bestTimes lap =
    Sector.map2 (BestTimes.timeOf >> rateTime) bestTimes.fastestSectors lap.sectors


type alias MiniSectorPerformance =
    ByMiniSector (Maybe RatedTime)


ofMiniSectors : BestTimes.Snapshot -> Lap -> Maybe MiniSectorPerformance
ofMiniSectors bestTimes lap =
    let
        rateOne miniSector fastest =
            rateTime (BestTimes.timeOf fastest)
                { time = miniSector.time, personalBest = miniSector.personalBest }
    in
    lap.miniSectors
        |> Maybe.map (\ms -> LeMans.map2 rateOne ms bestTimes.fastestMiniSectors)



-- HOW FAR THE CAR HAS GOT THROUGH A SEGMENT


{-| One segment of the lap a car is on -- a sector or a mini-sector -- as it
reads at a moment of the race.

Only `Completed` carries a rating, and that is the point of the type: the race
data holds every sector time of a lap from the start, the ones the car has not
driven yet included, so a shape that paired a rating with a progress would hand
a view the time a car is _going_ to set. Its `Maybe` is a segment the source
data has no time for.

-}
type SegmentState
    = NotEntered
    | InProgress Float
    | Completed (Maybe RatedTime)


{-| The state of the segment the car is currently inside, from how far through
it the clock puts them.

A progress of 1 is a segment behind the car, not one it is still in: callers
clamp progress to at most 1, so a clock past the end of the lap reads as exactly
1 of the final segment.

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

Both baselines are `Nothing` until some lap sets them, and an unset baseline
matches no time.

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


{-| The colour of a time still running, a segment the car is in or a lap it is
on, which has no rating until it is over.
-}
inProgressColor : String
inProgressColor =
    "var(--performance-in-progress)"


{-| The colour of a rating that may not exist. A time the source data has none
of takes the standard colour: there is nothing to rate it against.
-}
colorOf : Maybe PerformanceLevel -> String
colorOf =
    Maybe.withDefault Standard >> toColorVariable


{-| The colour of text carrying a rating, `inherit` for a standard one so that
it takes whatever colour the text around it already has.
-}
textColorOf : PerformanceLevel -> String
textColorOf level =
    if isStandard level then
        "inherit"

    else
        toColorVariable level
