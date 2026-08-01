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


{-| How a time reads against the two baselines it is rated on.

Both baselines are `Nothing` until some lap sets them, and nothing has beaten a
record that has not been set -- so an unset baseline matches no time, and the
comparison needs no guard of its own. There is only a time to rate here because
[`Lap.recorded`](Motorsport-Lap#recorded) has already dropped the ones the
source data did not record.

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
