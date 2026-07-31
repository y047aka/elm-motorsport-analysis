module Motorsport.Lap.Performance exposing
    ( RatedTime
    , PerformanceLevel(..), performanceLevel
    , isStandard
    , toColorVariable
    )

{-| How one time reads against the baseline it is rated on.

What that baseline is comes from [`BestTimes`](Motorsport-BestTimes); this module
only says what a time coloured against it looks like.

@docs RatedTime

@docs PerformanceLevel, performanceLevel
@docs isStandard
@docs toColorVariable

-}

import Motorsport.Duration exposing (Duration)


type alias RatedTime =
    { time : Duration
    , performance : PerformanceLevel
    }



-- PerformanceLevel


type PerformanceLevel
    = Fastest
    | PersonalBest
    | Standard


performanceLevel : { a | time : Duration, personalBest : Duration, fastest : Duration } -> PerformanceLevel
performanceLevel { time, personalBest, fastest } =
    if time == fastest then
        Fastest

    else if time == personalBest then
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
