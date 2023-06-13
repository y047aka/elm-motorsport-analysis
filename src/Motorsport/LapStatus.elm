module Motorsport.LapStatus exposing (LapStatus(..), lapStatus)

{-|

@docs LapStatus, lapStatus

-}

import Motorsport.Duration exposing (Duration)


type LapStatus
    = Fastest
    | PersonalBest
    | Normal


lapStatus : { a | time : Duration } -> { b | time : Duration, best : Duration } -> LapStatus
lapStatus fastestLap_ { time, best } =
    if time == fastestLap_.time then
        Fastest

    else if time == best then
        PersonalBest

    else
        Normal
