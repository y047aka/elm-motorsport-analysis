module Motorsport.Lap exposing
    ( Lap, empty
    , compareAt
    , personalBestLap, fastestLap, slowestLap
    , completedLapsAt, findLastLapAt, findCurrentLap
    , Sector(..), currentSector
    , MiniSector(..), currentMiniSector, miniSectorProgressAt
    , sectorToElapsed
    )

{-|

@docs Lap, empty
@docs compareAt
@docs personalBestLap, fastestLap, slowestLap
@docs completedLapsAt, findLastLapAt, findCurrentLap

@docs Sector, currentSector
@docs MiniSector, currentMiniSector, miniSectorProgressAt

-}

import List.Extra
import Motorsport.Duration exposing (Duration)


type alias Lap =
    { carNumber : String
    , driver : String
    , lap : Int
    , position : Maybe Int
    , time : Duration
    , best : Duration
    , sector_1 : Duration
    , sector_2 : Duration
    , sector_3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    , elapsed : Duration
    , miniSectors : Maybe MiniSectors
    }


type alias MiniSectors =
    { scl2 : MiniSectorData
    , z4 : MiniSectorData
    , ip1 : MiniSectorData
    , z12 : MiniSectorData
    , sclc : MiniSectorData
    , a7_1 : MiniSectorData
    , ip2 : MiniSectorData
    , a8_1 : MiniSectorData
    , sclb : MiniSectorData
    , porin : MiniSectorData
    , porout : MiniSectorData
    , pitref : MiniSectorData
    , scl1 : MiniSectorData
    , fordout : MiniSectorData
    , fl : MiniSectorData
    }


type alias MiniSectorData =
    { time : Maybe Duration
    , elapsed : Maybe Duration
    }


empty : Lap
empty =
    { carNumber = ""
    , driver = ""
    , lap = 0
    , position = Nothing
    , time = 0
    , sector_1 = 0
    , sector_2 = 0
    , sector_3 = 0
    , s1_best = 0
    , s2_best = 0
    , s3_best = 0
    , best = 0
    , elapsed = 0
    , miniSectors = Nothing
    }


type alias Clock =
    { elapsed : Duration }


compareAt : Clock -> Lap -> Lap -> Order
compareAt clock a b =
    case Basics.compare a.lap b.lap of
        LT ->
            GT

        EQ ->
            let
                currentSector_a =
                    currentSector clock a

                currentSector_b =
                    currentSector clock b
            in
            case Basics.compare (sectorToString currentSector_a) (sectorToString currentSector_b) of
                LT ->
                    GT

                EQ ->
                    Basics.compare (sectorToElapsed a currentSector_a) (sectorToElapsed b currentSector_b)

                GT ->
                    LT

        GT ->
            LT


personalBestLap : List { a | time : Duration } -> Maybe { a | time : Duration }
personalBestLap =
    List.filter (.time >> (/=) 0)
        >> List.Extra.minimumBy .time


fastestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
fastestLap =
    List.filterMap personalBestLap
        >> List.Extra.minimumBy .time


slowestLap : List (List { a | time : Duration }) -> Maybe { a | time : Duration }
slowestLap =
    List.filterMap (List.Extra.maximumBy .time)
        >> List.Extra.maximumBy .time


completedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
completedLapsAt clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)


imcompletedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
imcompletedLapsAt clock laps =
    let
        incompletedLaps =
            List.filter (\lap -> lap.elapsed > clock.elapsed) laps
    in
    case incompletedLaps of
        [] ->
            List.filterMap identity [ List.Extra.last laps ]

        _ ->
            incompletedLaps


findLastLapAt : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findLastLapAt clock =
    completedLapsAt clock >> List.Extra.last


findCurrentLap : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findCurrentLap clock =
    imcompletedLapsAt clock >> List.head



-- SECTOR


type Sector
    = S1
    | S2
    | S3


currentSector : Clock -> Lap -> Sector
currentSector clock lap =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    if clock.elapsed >= elapsed_lastLap && clock.elapsed < (elapsed_lastLap + lap.sector_1) then
        S1

    else if clock.elapsed >= (elapsed_lastLap + lap.sector_1) && clock.elapsed < (elapsed_lastLap + lap.sector_1 + lap.sector_2) then
        S2

    else
        S3


sectorToString : Sector -> String
sectorToString sector =
    case sector of
        S1 ->
            "S1"

        S2 ->
            "S2"

        S3 ->
            "S3"


sectorToElapsed : Lap -> Sector -> Duration
sectorToElapsed lap sector =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    case sector of
        S1 ->
            elapsed_lastLap

        S2 ->
            elapsed_lastLap + lap.sector_1

        S3 ->
            elapsed_lastLap + lap.sector_1 + lap.sector_2


type MiniSector
    = SCL2
    | Z4
    | IP1
    | Z12
    | SCLC
    | A7_1
    | IP2
    | A8_1
    | SCLB
    | PORIN
    | POROUT
    | PITREF
    | SCL1
    | FORDOUT
    | FL


currentMiniSector : Clock -> Lap -> Maybe MiniSector
currentMiniSector clock lap =
    lap.miniSectors
        |> Maybe.andThen
            (\ms ->
                let
                    elapsed_lastLap =
                        lap.elapsed - lap.time

                    inRange start end =
                        case ( start, end ) of
                            ( Just start_, Just end_ ) ->
                                clock.elapsed >= (start_ + elapsed_lastLap) && clock.elapsed < (end_ + elapsed_lastLap)

                            _ ->
                                False

                    miniSectorRanges =
                        [ ( SCL2, Just elapsed_lastLap, ms.scl2.elapsed )
                        , ( Z4, ms.scl2.elapsed, ms.z4.elapsed )
                        , ( IP1, ms.z4.elapsed, ms.ip1.elapsed )
                        , ( Z12, ms.ip1.elapsed, ms.z12.elapsed )
                        , ( SCLC, ms.z12.elapsed, ms.sclc.elapsed )
                        , ( A7_1, ms.sclc.elapsed, ms.a7_1.elapsed )
                        , ( IP2, ms.a7_1.elapsed, ms.ip2.elapsed )
                        , ( A8_1, ms.ip2.elapsed, ms.a8_1.elapsed )
                        , ( SCLB, ms.a8_1.elapsed, ms.sclb.elapsed )
                        , ( PORIN, ms.sclb.elapsed, ms.porin.elapsed )
                        , ( POROUT, ms.porin.elapsed, ms.porout.elapsed )
                        , ( PITREF, ms.porout.elapsed, ms.pitref.elapsed )
                        , ( SCL1, ms.pitref.elapsed, ms.scl1.elapsed )
                        , ( FORDOUT, ms.scl1.elapsed, ms.fordout.elapsed )
                        , ( FL, ms.fordout.elapsed, ms.fl.elapsed )
                        ]
                in
                miniSectorRanges
                    |> List.Extra.find (\( _, start, end ) -> inRange start end)
                    |> Maybe.map (\( miniSector, _, _ ) -> miniSector)
            )


miniSectorProgressAt : Clock -> ( Lap, Lap ) -> Maybe ( MiniSector, Float )
miniSectorProgressAt clock ( currentLap, lastLap ) =
    case currentMiniSector clock currentLap of
        Just SCL2 ->
            Just ( SCL2, min 1 (toFloat (clock.elapsed - lastLap.elapsed) / toFloat (currentLap.miniSectors |> Maybe.andThen (.scl2 >> .time) |> Maybe.withDefault 0)) )

        Just Z4 ->
            Just ( Z4, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.scl2 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.z4 >> .time) |> Maybe.withDefault 0)) )

        Just IP1 ->
            Just ( IP1, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.z4 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.ip1 >> .time) |> Maybe.withDefault 0)) )

        Just Z12 ->
            Just ( Z12, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.ip1 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.z12 >> .time) |> Maybe.withDefault 0)) )

        Just SCLC ->
            Just ( SCLC, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.z12 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.sclc >> .time) |> Maybe.withDefault 0)) )

        Just A7_1 ->
            Just ( A7_1, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.sclc >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.a7_1 >> .time) |> Maybe.withDefault 0)) )

        Just IP2 ->
            Just ( IP2, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.a7_1 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.ip2 >> .time) |> Maybe.withDefault 0)) )

        Just A8_1 ->
            Just ( A8_1, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.ip2 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.a8_1 >> .time) |> Maybe.withDefault 0)) )

        Just SCLB ->
            Just ( SCLB, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.a8_1 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.sclb >> .time) |> Maybe.withDefault 0)) )

        Just PORIN ->
            Just ( PORIN, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.sclb >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.porin >> .time) |> Maybe.withDefault 0)) )

        Just POROUT ->
            Just ( POROUT, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.porin >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.porout >> .time) |> Maybe.withDefault 0)) )

        Just PITREF ->
            Just ( PITREF, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.porout >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.pitref >> .time) |> Maybe.withDefault 0)) )

        Just SCL1 ->
            Just ( SCL1, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.pitref >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.scl1 >> .time) |> Maybe.withDefault 0)) )

        Just FORDOUT ->
            Just ( FORDOUT, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.scl1 >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.fordout >> .time) |> Maybe.withDefault 0)) )

        Just FL ->
            Just ( FL, min 1 (toFloat (clock.elapsed - (currentLap.miniSectors |> Maybe.andThen (.fordout >> .elapsed) |> Maybe.withDefault 0)) / toFloat (currentLap.miniSectors |> Maybe.andThen (.fl >> .time) |> Maybe.withDefault 0)) )

        Nothing ->
            Nothing


miniSectorToString : MiniSector -> String
miniSectorToString miniSector =
    case miniSector of
        SCL2 ->
            "SCL2"

        Z4 ->
            "Z4"

        IP1 ->
            "IP1"

        Z12 ->
            "Z12"

        SCLC ->
            "SCLC"

        A7_1 ->
            "A7-1"

        IP2 ->
            "IP2"

        A8_1 ->
            "A8-1"

        SCLB ->
            "SCLB"

        PORIN ->
            "PORIN"

        POROUT ->
            "POROUT"

        PITREF ->
            "PITREF"

        SCL1 ->
            "SCL1"

        FORDOUT ->
            "FORDOUT"

        FL ->
            "FL"


miniSectorToElapsed : Lap -> MiniSector -> Duration
miniSectorToElapsed lap miniSector =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    case miniSector of
        SCL2 ->
            elapsed_lastLap

        Z4 ->
            lap.miniSectors |> Maybe.andThen (.scl2 >> .elapsed) |> Maybe.withDefault 0

        IP1 ->
            lap.miniSectors |> Maybe.andThen (.z4 >> .elapsed) |> Maybe.withDefault 0

        Z12 ->
            lap.miniSectors |> Maybe.andThen (.ip1 >> .elapsed) |> Maybe.withDefault 0

        SCLC ->
            lap.miniSectors |> Maybe.andThen (.z12 >> .elapsed) |> Maybe.withDefault 0

        A7_1 ->
            lap.miniSectors |> Maybe.andThen (.sclc >> .elapsed) |> Maybe.withDefault 0

        IP2 ->
            lap.miniSectors |> Maybe.andThen (.a7_1 >> .elapsed) |> Maybe.withDefault 0

        A8_1 ->
            lap.miniSectors |> Maybe.andThen (.ip2 >> .elapsed) |> Maybe.withDefault 0

        SCLB ->
            lap.miniSectors |> Maybe.andThen (.a8_1 >> .elapsed) |> Maybe.withDefault 0

        PORIN ->
            lap.miniSectors |> Maybe.andThen (.sclb >> .elapsed) |> Maybe.withDefault 0

        POROUT ->
            lap.miniSectors |> Maybe.andThen (.porin >> .elapsed) |> Maybe.withDefault 0

        PITREF ->
            lap.miniSectors |> Maybe.andThen (.porout >> .elapsed) |> Maybe.withDefault 0

        SCL1 ->
            lap.miniSectors |> Maybe.andThen (.pitref >> .elapsed) |> Maybe.withDefault 0

        FORDOUT ->
            lap.miniSectors |> Maybe.andThen (.scl1 >> .elapsed) |> Maybe.withDefault 0

        FL ->
            lap.miniSectors |> Maybe.andThen (.fordout >> .elapsed) |> Maybe.withDefault 0
