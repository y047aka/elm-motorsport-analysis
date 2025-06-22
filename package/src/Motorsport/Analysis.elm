module Motorsport.Analysis exposing (Analysis, finished, fromRaceControl)

import Dict exposing (Dict)
import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap, MiniSector(..), completedLapsAt, fastestLap, slowestLap)


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


type alias Analysis =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    , sector_1_fastest : Duration
    , sector_2_fastest : Duration
    , sector_3_fastest : Duration
    , miniSectorFastest : MiniSectorFastest
    }


fromRaceControl : { a | clock : Clock.Model, cars : List Car } -> Analysis
fromRaceControl { clock, cars } =
    let
        raceClock =
            { elapsed = Clock.getElapsed clock }

        completedLaps =
            List.map (.laps >> completedLapsAt raceClock) cars
    in
    { fastestLapTime = completedLaps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest =
        completedLaps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_1)
            |> List.Extra.minimumBy .sector_1
            |> Maybe.map .sector_1
            |> Maybe.withDefault 0
    , sector_2_fastest =
        completedLaps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_2)
            |> List.Extra.minimumBy .sector_2
            |> Maybe.map .sector_2
            |> Maybe.withDefault 0
    , sector_3_fastest =
        completedLaps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_3)
            |> List.Extra.minimumBy .sector_3
            |> Maybe.map .sector_3
            |> Maybe.withDefault 0
    , miniSectorFastest = calculateMiniSectorFastest completedLaps
    }


finished : { a | cars : List Car } -> Analysis
finished { cars } =
    let
        laps =
            List.map .laps cars
    in
    { fastestLapTime = laps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = laps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    , sector_1_fastest =
        laps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_1)
            |> List.Extra.minimumBy .sector_1
            |> Maybe.map .sector_1
            |> Maybe.withDefault 0
    , sector_2_fastest =
        laps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_2)
            |> List.Extra.minimumBy .sector_2
            |> Maybe.map .sector_2
            |> Maybe.withDefault 0
    , sector_3_fastest =
        laps
            |> List.filterMap (List.filter (.time >> (/=) 0) >> List.Extra.minimumBy .sector_3)
            |> List.Extra.minimumBy .sector_3
            |> Maybe.map .sector_3
            |> Maybe.withDefault 0
    , miniSectorFastest = calculateMiniSectorFastest laps
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
