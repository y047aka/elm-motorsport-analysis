module Motorsport.LapStatus exposing
    ( LapStatus, lapStatus
    , isNormal
    , toHexColorString
    )

{-|

@docs LapStatus, lapStatus
@docs isNormal
@docs toHexColorString

-}

import Motorsport.Duration exposing (Duration)


type LapStatus
    = Fastest
    | PersonalBest
    | Normal


lapStatus : { a | time : Duration, personalBest : Duration, overallBest : Duration } -> LapStatus
lapStatus { time, personalBest, overallBest } =
    if time == overallBest then
        Fastest

    else if time == personalBest then
        PersonalBest

    else
        Normal


isNormal : LapStatus -> Bool
isNormal status =
    status == Normal


toHexColorString : LapStatus -> String
toHexColorString status =
    case status of
        Fastest ->
            "#F0F"

        PersonalBest ->
            "#0C0"

        Normal ->
            "#FC0"
