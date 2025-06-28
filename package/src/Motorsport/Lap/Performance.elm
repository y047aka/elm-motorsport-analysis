module Motorsport.Lap.Performance exposing
    ( PerformanceLevel, performanceLevel
    , isStandard
    , toHexColorString
    )

{-|

@docs PerformanceLevel, performanceLevel
@docs isStandard
@docs toHexColorString

-}

import Motorsport.Duration exposing (Duration)


type PerformanceLevel
    = OverallBest
    | PersonalBest
    | Standard


performanceLevel : { a | time : Duration, personalBest : Duration, overallBest : Duration } -> PerformanceLevel
performanceLevel { time, personalBest, overallBest } =
    if time == overallBest then
        OverallBest

    else if time == personalBest then
        PersonalBest

    else
        Standard


isStandard : PerformanceLevel -> Bool
isStandard level =
    level == Standard


toHexColorString : PerformanceLevel -> String
toHexColorString level =
    case level of
        OverallBest ->
            "#F0F"

        PersonalBest ->
            "#0C0"

        Standard ->
            "#FC0"
