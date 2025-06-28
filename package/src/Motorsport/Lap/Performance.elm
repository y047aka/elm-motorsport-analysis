module Motorsport.Lap.Performance exposing
    ( PerformanceLevel, lapStatus
    , isNormal
    , toHexColorString
    )

{-|

@docs PerformanceLevel, lapStatus
@docs isNormal
@docs toHexColorString

-}

import Motorsport.Duration exposing (Duration)


type PerformanceLevel
    = Fastest
    | PersonalBest
    | Normal


lapStatus : { a | time : Duration, personalBest : Duration, overallBest : Duration } -> PerformanceLevel
lapStatus { time, personalBest, overallBest } =
    if time == overallBest then
        Fastest

    else if time == personalBest then
        PersonalBest

    else
        Normal


isNormal : PerformanceLevel -> Bool
isNormal status =
    status == Normal


toHexColorString : PerformanceLevel -> String
toHexColorString status =
    case status of
        Fastest ->
            "#F0F"

        PersonalBest ->
            "#0C0"

        Normal ->
            "#FC0"
