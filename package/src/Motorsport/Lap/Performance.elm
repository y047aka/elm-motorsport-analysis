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


{-| A zero is a time the source data did not record, not a very quick one, so it
takes no colour.

Without that first branch it would take both. Nothing has beaten a record that
has not been set, so an unset baseline reads as zero -- and a zero time matches
it exactly, which would light up every unrecorded time as the fastest of the
race until the first real one is set. A car that has yet to set a personal best
carries a zero for the same reason, and would rate its own missing time as one.

-}
performanceLevel : { a | time : Duration, personalBest : Duration, fastest : Duration } -> PerformanceLevel
performanceLevel { time, personalBest, fastest } =
    if time == 0 then
        Standard

    else if time == fastest then
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
