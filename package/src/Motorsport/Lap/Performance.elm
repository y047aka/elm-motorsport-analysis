module Motorsport.Lap.Performance exposing
    ( findPersonalBest, findFastest, findFastestBy, findSlowest
    , calculateMiniSectorFastest, MiniSectorFastest
    , PerformanceLevel, performanceLevel
    , isStandard
    , toColorVariable
    )

{-|

@docs findPersonalBest, findFastest, findFastestBy, findSlowest
@docs calculateMiniSectorFastest, MiniSectorFastest

@docs PerformanceLevel, performanceLevel
@docs isStandard
@docs toColorVariable

-}

import List.Extra
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)


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


findFastestBy : (a -> Duration) -> List (List a) -> Maybe Duration
findFastestBy getter laps =
    laps
        |> List.filterMap (List.filter (getter >> (/=) 0) >> List.Extra.minimumBy getter)
        |> List.Extra.minimumBy getter
        |> Maybe.map getter



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



-- MiniSectorFastest


type alias MiniSectorFastest =
    { scl2 : Duration
    , z4 : Duration
    , ip1 : Duration
    , z12 : Duration
    , sclc : Duration
    , a7_1 : Duration
    , ip2 : Duration
    , a8_1 : Duration
    , sclb : Duration
    , porin : Duration
    , porout : Duration
    , pitref : Duration
    , scl1 : Duration
    , fordout : Duration
    , fl : Duration
    }


calculateMiniSectorFastest : List (List Lap) -> MiniSectorFastest
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
    { scl2 = fastestTimeFor .scl2
    , z4 = fastestTimeFor .z4
    , ip1 = fastestTimeFor .ip1
    , z12 = fastestTimeFor .z12
    , sclc = fastestTimeFor .sclc
    , a7_1 = fastestTimeFor .a7_1
    , ip2 = fastestTimeFor .ip2
    , a8_1 = fastestTimeFor .a8_1
    , sclb = fastestTimeFor .sclb
    , porin = fastestTimeFor .porin
    , porout = fastestTimeFor .porout
    , pitref = fastestTimeFor .pitref
    , scl1 = fastestTimeFor .scl1
    , fordout = fastestTimeFor .fordout
    , fl = fastestTimeFor .fl
    }
