module Motorsport.Lap.Performance exposing
    ( findPersonalBest, findFastest, findSlowest
    , PerformanceLevel, performanceLevel
    , isStandard
    , toHexColorString
    )

{-|

@docs findPersonalBest, findFastest, findSlowest

@docs PerformanceLevel, performanceLevel
@docs isStandard
@docs toHexColorString

-}

import List.Extra
import Motorsport.Duration exposing (Duration)


findPersonalBest : List { a | time : Duration } -> Maybe { a | time : Duration }
findPersonalBest =
    List.filter (.time >> (/=) 0)
        >> List.Extra.minimumBy .time


findFastest : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
findFastest =
    List.filterMap findPersonalBest
        >> List.Extra.minimumBy .time


findSlowest : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
findSlowest =
    List.filterMap (List.Extra.maximumBy .time)
        >> List.Extra.maximumBy .time



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


toHexColorString : PerformanceLevel -> String
toHexColorString level =
    case level of
        Fastest ->
            "#F0F"

        PersonalBest ->
            "#0C0"

        Standard ->
            "#FC0"
