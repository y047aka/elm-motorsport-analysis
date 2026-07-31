module Motorsport.Lap.Performance exposing
    ( findFastestBy
    , calculateMiniSectorFastest
    , RatedTime
    , PerformanceLevel(..), performanceLevel
    , isStandard
    , toColorVariable
    )

{-|

@docs findFastestBy
@docs calculateMiniSectorFastest

@docs RatedTime

@docs PerformanceLevel, performanceLevel
@docs isStandard
@docs toColorVariable

-}

import List.Extra
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)


findFastestBy : (a -> Duration) -> List (List a) -> Maybe Duration
findFastestBy getter laps =
    laps
        |> List.filterMap (List.filter (getter >> (/=) 0) >> List.Extra.minimumBy getter)
        |> List.Extra.minimumBy getter
        |> Maybe.map getter


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



-- FASTEST MINI SECTORS


calculateMiniSectorFastest : List (List Lap) -> ByMiniSector Duration
calculateMiniSectorFastest laps =
    let
        validLaps =
            List.map (List.filter (.time >> (/=) 0)) laps

        fastestTimeFor getter =
            validLaps
                |> List.filterMap
                    (\laps_ ->
                        laps_
                            |> List.filterMap (\lap -> lap.miniSectors |> Maybe.andThen (getter >> .time))
                            |> List.filter ((/=) 0)
                            |> List.minimum
                    )
                |> List.minimum
                |> Maybe.withDefault 0
    in
    -- TODO: 畳み込みを使うとより高速に計算できる
    LeMans.initialize (\mini -> fastestTimeFor (LeMans.get mini))
