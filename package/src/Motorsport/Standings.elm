module Motorsport.Standings exposing
    ( Standings, StandingsEntry
    , SectorProgress, MiniSectorProgress
    , SectorTimes
    , SectorPerformance, MiniSectorPerformance
    , init, fromLaps, fromList
    , toList, toClassList, leader, lapCount
    , getCarHistory
    , groupCarsByCloseIntervals
    , getRecentLaps
    )

{-|

@docs Standings, StandingsEntry
@docs SectorProgress, MiniSectorProgress
@docs SectorTimes
@docs SectorPerformance, MiniSectorPerformance
@docs init, fromLaps, fromList

@docs toList, toClassList, leader, lapCount

@docs getCarHistory

@docs groupCarsByCloseIntervals

@docs getRecentLaps

-}

import Dict exposing (Dict)
import List.Extra
import Motorsport.Car as Car exposing (Car, Status)
import Motorsport.Circuit.LeMans exposing (LeMans2025MiniSector)
import Motorsport.Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap, MiniSectors, completedLapsAt)
import Motorsport.Lap.Performance exposing (LeMans2025MiniSectorFastest, PerformanceLevel(..), RatedTime, calculateMiniSectorFastest, findFastestBy, performanceLevel)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)
import Motorsport.Sector exposing (Sector(..))
import SortedList exposing (SortedList)


type Standings
    = Standings
        { laps : Int
        , entries : SortedList ByPosition StandingsEntry
        , entriesByClass : List ( Class, SortedList ByPosition StandingsEntry )
        , lapHistory : Dict String (List Lap)
        }


type alias SectorTimes =
    { sector_1 : Duration
    , sector_2 : Duration
    , sector_3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    }


type alias SectorPerformance =
    { sector_1 : RatedTime
    , sector_2 : RatedTime
    , sector_3 : RatedTime
    }


type alias MiniSectorPerformance =
    { scl2 : Maybe RatedTime
    , z4 : Maybe RatedTime
    , ip1 : Maybe RatedTime
    , z12 : Maybe RatedTime
    , sclc : Maybe RatedTime
    , a7_1 : Maybe RatedTime
    , ip2 : Maybe RatedTime
    , a8_1 : Maybe RatedTime
    , sclb : Maybe RatedTime
    , porin : Maybe RatedTime
    , porout : Maybe RatedTime
    , pitref : Maybe RatedTime
    , scl1 : Maybe RatedTime
    , fordout : Maybe RatedTime
    , fl : Maybe RatedTime
    }


type alias StandingsEntry =
    { position : Int
    , positionInClass : Int
    , status : Status
    , metadata : Car.Metadata
    , lapsCompleted : Int
    , currentLapTime : Maybe Duration
    , currentLapBest : Maybe Duration
    , currentLapSectors : Maybe SectorTimes
    , currentLapMiniSectors : Maybe MiniSectors
    , currentLapElapsed : Duration
    , sector : Maybe SectorProgress
    , miniSector : Maybe MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    , currentLapProgress : Float
    , lastLap : Maybe RatedTime
    , bestLap : Maybe RatedTime
    , lastLapSectors : Maybe SectorPerformance
    , lastLapMiniSectors : Maybe MiniSectorPerformance
    , currentDriver : Maybe Driver
    }


type alias SectorProgress =
    { sector : Sector
    , progress : Float
    }


type alias MiniSectorProgress =
    { miniSector : LeMans2025MiniSector
    , progress : Float
    }


init :
    { a
        | fastestLapTime : Duration
        , sector_1_fastest : Duration
        , sector_2_fastest : Duration
        , sector_3_fastest : Duration
        , miniSectorFastest : LeMans2025MiniSectorFastest
    }
    -> { elapsed : Duration, lapCount : Int, cars : RunningOrder }
    -> Standings
init fastest config =
    let
        carsList =
            RunningOrder.toList config.cars

        leaderCar =
            RunningOrder.leader config.cars

        positionsInClass =
            positionsInClassByCarNumber config.cars

        raceClock =
            { elapsed = config.elapsed }

        entries =
            carsList
                |> List.indexedMap
                    (\index car ->
                        let
                            metadata =
                                car.metadata

                            positionInClass =
                                Dict.get car.metadata.carNumber positionsInClass
                                    |> Maybe.withDefault 1

                            lastLap =
                                Maybe.withDefault Lap.empty car.lastLap

                            currentLap =
                                car.currentLap

                            timing =
                                init_timing config.elapsed
                                    { leader = Just leaderCar
                                    , rival = List.Extra.getAt (index - 1) carsList
                                    }
                                    car
                        in
                        { position = index + 1
                        , positionInClass = positionInClass
                        , status = car.status
                        , metadata = metadata
                        , lapsCompleted = lastLap.lap
                        , currentLapTime = currentLap |> Maybe.map .time
                        , currentLapBest = currentLap |> Maybe.map .best
                        , currentLapSectors = currentLap |> Maybe.map extractSectorTimes
                        , currentLapMiniSectors = currentLap |> Maybe.andThen .miniSectors
                        , currentLapElapsed = timing.currentLapElapsed
                        , sector = timing.sector
                        , miniSector = timing.miniSector
                        , gapToLeader = timing.gapToLeader
                        , intervalToAhead = timing.intervalToAhead
                        , currentLapProgress =
                            currentLap
                                |> Maybe.map (\lap -> min 1.0 (toFloat timing.currentLapElapsed / toFloat lap.time))
                                |> Maybe.withDefault 0
                        , lastLap =
                            car.lastLap
                                |> Maybe.map (\lap -> rateTime fastest.fastestLapTime { time = lap.time, personalBest = lap.best })
                        , bestLap =
                            car.lastLap
                                |> Maybe.map (\lap -> rateTime fastest.fastestLapTime { time = lap.best, personalBest = lap.best })
                        , lastLapSectors = car.lastLap |> Maybe.map (extractSectorPerformance fastest)
                        , lastLapMiniSectors = car.lastLap |> Maybe.andThen (extractMiniSectorPerformance fastest)
                        , currentDriver = car.currentDriver
                        }
                    )

        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { laps = config.lapCount
        , entries = sortedEntries
        , entriesByClass =
            sortedEntries
                |> SortedList.gatherEqualsBy (.metadata >> .class)
                |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
        , lapHistory =
            carsList
                |> List.map (\car -> ( car.metadata.carNumber, completedLapsAt raceClock car.laps ))
                |> Dict.fromList
        }


{-| デバッグ用: 1台分のラップリストから Standings を組み立てる。

各ラップを1つの StandingsEntry として扱い、`metadata.carNumber` にラップ番号文字列をセットする。
`lapHistory` / `carLapData` はラップ番号文字列をキーとして構築されるため、不変条件が保たれる。

-}
fromLaps : Car.Metadata -> List Lap -> Standings
fromLaps baseMetadata laps =
    let
        fastest =
            { fastestLapTime = laps |> List.map .time |> List.filter ((/=) 0) |> List.minimum |> Maybe.withDefault 0
            , sector_1_fastest = [ laps ] |> findFastestBy .sector_1 |> Maybe.withDefault 0
            , sector_2_fastest = [ laps ] |> findFastestBy .sector_2 |> Maybe.withDefault 0
            , sector_3_fastest = [ laps ] |> findFastestBy .sector_3 |> Maybe.withDefault 0
            , miniSectorFastest = calculateMiniSectorFastest [ laps ]
            }

        entries =
            laps
                |> List.indexedMap
                    (\index lap ->
                        { position = index + 1
                        , positionInClass = index + 1
                        , status = Car.Racing
                        , metadata = { baseMetadata | carNumber = String.fromInt lap.lap }
                        , lapsCompleted = lap.lap
                        , currentLapTime = Just lap.time
                        , currentLapBest = Just lap.best
                        , currentLapSectors = Just (extractSectorTimes lap)
                        , currentLapMiniSectors = lap.miniSectors
                        , currentLapElapsed = 0
                        , sector = Nothing
                        , miniSector = Nothing
                        , gapToLeader = Gap.None
                        , intervalToAhead = Gap.None
                        , currentLapProgress = 0
                        , lastLap =
                            Just (rateTime fastest.fastestLapTime { time = lap.time, personalBest = lap.best })
                        , bestLap =
                            Just (rateTime fastest.fastestLapTime { time = lap.best, personalBest = lap.best })
                        , lastLapSectors = Just (extractSectorPerformance fastest lap)
                        , lastLapMiniSectors = extractMiniSectorPerformance fastest lap
                        , currentDriver = Just lap.driver
                        }
                    )

        sortedEntries =
            Ordering.byPosition entries

        lapKey lap =
            String.fromInt lap.lap
    in
    Standings
        { laps = laps |> List.map .lap |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass =
            sortedEntries
                |> SortedList.gatherEqualsBy (.metadata >> .class)
                |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
        , lapHistory =
            laps
                |> List.map (\lap -> ( lapKey lap, [ lap ] ))
                |> Dict.fromList
        }


{-| `StandingsEntry` のリストから `Standings` を組み立てる。テスト用途などで直接エントリを指定したい場合に使う。
-}
fromList : List StandingsEntry -> Standings
fromList entries =
    let
        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { laps = entries |> List.map .lapsCompleted |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass =
            sortedEntries
                |> SortedList.gatherEqualsBy (.metadata >> .class)
                |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
        , lapHistory = Dict.empty
        }


rateTime : Duration -> { time : Duration, personalBest : Duration } -> RatedTime
rateTime fastest { time, personalBest } =
    { time = time
    , performance = performanceLevel { time = time, personalBest = personalBest, fastest = fastest }
    }


extractSectorTimes : Lap -> SectorTimes
extractSectorTimes lap =
    { sector_1 = lap.sector_1
    , sector_2 = lap.sector_2
    , sector_3 = lap.sector_3
    , s1_best = lap.s1_best
    , s2_best = lap.s2_best
    , s3_best = lap.s3_best
    }


extractSectorPerformance :
    { a | sector_1_fastest : Duration, sector_2_fastest : Duration, sector_3_fastest : Duration }
    -> Lap
    -> SectorPerformance
extractSectorPerformance fastest lap =
    { sector_1 = rateTime fastest.sector_1_fastest { time = lap.sector_1, personalBest = lap.s1_best }
    , sector_2 = rateTime fastest.sector_2_fastest { time = lap.sector_2, personalBest = lap.s2_best }
    , sector_3 = rateTime fastest.sector_3_fastest { time = lap.sector_3, personalBest = lap.s3_best }
    }


extractMiniSectorPerformance :
    { a | miniSectorFastest : LeMans2025MiniSectorFastest }
    -> Lap
    -> Maybe MiniSectorPerformance
extractMiniSectorPerformance fastest lap =
    lap.miniSectors
        |> Maybe.map
            (\ms ->
                let
                    rateMiniSector msd fastestTime =
                        Maybe.map2
                            (\t b -> rateTime fastestTime { time = t, personalBest = b })
                            msd.time
                            msd.best
                in
                { scl2 = rateMiniSector ms.scl2 fastest.miniSectorFastest.scl2
                , z4 = rateMiniSector ms.z4 fastest.miniSectorFastest.z4
                , ip1 = rateMiniSector ms.ip1 fastest.miniSectorFastest.ip1
                , z12 = rateMiniSector ms.z12 fastest.miniSectorFastest.z12
                , sclc = rateMiniSector ms.sclc fastest.miniSectorFastest.sclc
                , a7_1 = rateMiniSector ms.a7_1 fastest.miniSectorFastest.a7_1
                , ip2 = rateMiniSector ms.ip2 fastest.miniSectorFastest.ip2
                , a8_1 = rateMiniSector ms.a8_1 fastest.miniSectorFastest.a8_1
                , sclb = rateMiniSector ms.sclb fastest.miniSectorFastest.sclb
                , porin = rateMiniSector ms.porin fastest.miniSectorFastest.porin
                , porout = rateMiniSector ms.porout fastest.miniSectorFastest.porout
                , pitref = rateMiniSector ms.pitref fastest.miniSectorFastest.pitref
                , scl1 = rateMiniSector ms.scl1 fastest.miniSectorFastest.scl1
                , fordout = rateMiniSector ms.fordout fastest.miniSectorFastest.fordout
                , fl = rateMiniSector ms.fl fastest.miniSectorFastest.fl
                }
            )


{-| carNumber からラップ履歴を取得する
-}
getCarHistory : String -> Standings -> List Lap
getCarHistory carNumber (Standings s) =
    Dict.get carNumber s.lapHistory
        |> Maybe.withDefault []



type alias TimingState =
    { currentLapElapsed : Duration
    , sector : Maybe SectorProgress
    , miniSector : Maybe MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


init_timing : Duration -> { leader : Maybe Car, rival : Maybe Car } -> Car -> TimingState
init_timing elapsed rivals car =
    let
        raceClock =
            { elapsed = elapsed }

        currentLap =
            Maybe.withDefault Lap.empty car.currentLap

        lastLap =
            Maybe.withDefault Lap.empty car.lastLap

        currentSector =
            case Lap.currentSector raceClock currentLap of
                S1 ->
                    Just { sector = S1, progress = min 100 ((toFloat (raceClock.elapsed - lastLap.elapsed) / toFloat currentLap.sector_1) * 100) }

                S2 ->
                    Just { sector = S2, progress = min 100 ((toFloat (raceClock.elapsed - (lastLap.elapsed + currentLap.sector_1)) / toFloat currentLap.sector_2) * 100) }

                S3 ->
                    Just { sector = S3, progress = min 100 ((toFloat (raceClock.elapsed - (lastLap.elapsed + currentLap.sector_1 + currentLap.sector_2)) / toFloat currentLap.sector_3) * 100) }

        currentMiniSector =
            Lap.miniSectorProgressAt raceClock ( currentLap, lastLap )
                |> Maybe.map (\( ms, p ) -> { miniSector = ms, progress = p })
    in
    { currentLapElapsed = raceClock.elapsed - lastLap.elapsed
    , sector = currentSector
    , miniSector = currentMiniSector
    , gapToLeader =
        Maybe.map2 (Gap.at elapsed) rivals.leader (Just car)
            |> Maybe.withDefault Gap.None
    , intervalToAhead =
        Maybe.map2 (Gap.at elapsed) rivals.rival (Just car)
            |> Maybe.withDefault Gap.None
    }


positionsInClassByCarNumber : RunningOrder -> Dict String Int
positionsInClassByCarNumber raceOrder =
    raceOrder
        |> RunningOrder.toList
        |> List.Extra.gatherEqualsBy (.metadata >> .class)
        |> List.concatMap
            (\( firstCar, restCars ) ->
                (firstCar :: restCars)
                    |> List.indexedMap (\index car -> ( car.metadata.carNumber, index + 1 ))
            )
        |> Dict.fromList


toList : Standings -> List StandingsEntry
toList (Standings s) =
    SortedList.toList s.entries


toClassList : Standings -> List ( Class, List StandingsEntry )
toClassList (Standings s) =
    s.entriesByClass
        |> List.map (Tuple.mapSecond SortedList.toList)


leader : Standings -> Maybe StandingsEntry
leader (Standings s) =
    SortedList.head s.entries


lapCount : Standings -> Int
lapCount (Standings s) =
    s.laps


groupCarsByCloseIntervals : Standings -> List (List StandingsEntry)
groupCarsByCloseIntervals (Standings s) =
    let
        isCloseToNext current =
            case current.intervalToAhead of
                Gap.Seconds duration ->
                    duration <= 1500

                _ ->
                    False

        groupCars cars =
            case cars of
                [] ->
                    []

                first :: rest ->
                    let
                        ( group, remaining ) =
                            List.Extra.span isCloseToNext rest
                    in
                    (first :: group) :: groupCars remaining
    in
    SortedList.toList s.entries
        |> groupCars
        |> List.filter (\group -> List.length group >= 2)


getRecentLaps : { count : Int, currentLap : Int } -> List Lap -> List Lap
getRecentLaps { count, currentLap } lapList =
    let
        targetRange =
            List.range (currentLap - count) currentLap
    in
    lapList
        |> List.filter (\lap -> List.member lap.lap targetRange)
        |> List.sortBy .lap
