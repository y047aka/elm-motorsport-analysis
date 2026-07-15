module Motorsport.ViewModel.Standings exposing
    ( Standings, Entry, ClassInfo
    , SectorProgress, MiniSectorProgress
    , SectorTimes, CurrentSectorSlots
    , SectorPerformance, MiniSectorPerformance
    , compute, fromLaps, fromList
    , toList, toClassList, leader, lapCount, elapsed
    , classInfoOf
    , groupCarsByCloseIntervals
    )

{-|

@docs Standings, Entry, ClassInfo
@docs SectorProgress, MiniSectorProgress
@docs SectorTimes, CurrentSectorSlots
@docs SectorPerformance, MiniSectorPerformance
@docs compute, fromLaps, fromList

@docs toList, toClassList, leader, lapCount, elapsed

@docs classInfoOf

@docs groupCarsByCloseIntervals

-}

import Css
import Dict exposing (Dict)
import List.Extra
import Motorsport.Car as Car exposing (Car, Status)
import Motorsport.Circuit.LeMans exposing (LeMans2025MiniSector)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap, MiniSectors)
import Motorsport.Lap.Performance exposing (LeMans2025MiniSectorFastest, RatedTime, calculateMiniSectorFastest, findFastestBy, performanceLevel)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)
import Motorsport.Sector exposing (Sector(..))
import SortedList exposing (SortedList)


type Standings
    = Standings
        { elapsed : Duration
        , laps : Int
        , entries : SortedList ByPosition Entry
        , entriesByClass : List ( ClassInfo, SortedList ByPosition Entry )
        }


{-| クラス見出し・バッジが必要とする表示情報。
season 依存の色解決は compute 時に済ませてある。
-}
type alias ClassInfo =
    { class : Class
    , name : String
    , color : Css.Color
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


type alias Entry =
    { position : Int
    , positionInClass : Int
    , status : Status
    , metadata : Car.Metadata
    , classColor : Css.Color
    , lapsCompleted : Int
    , currentLapTime : Maybe Duration
    , currentLapBest : Maybe Duration
    , currentLapSectors : Maybe SectorTimes
    , currentLapSectorSlots : Maybe CurrentSectorSlots
    , currentLapMiniSectors : Maybe MiniSectors
    , currentLapElapsed : Duration
    , currentLapRated : Maybe RatedTime
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


{-| 現在ラップのセクターごとの「進捗 + 性能判定」。
donut 表示などが Analysis を追加供給されずに描けるよう、compute 時に判定済み。
-}
type alias CurrentSectorSlots =
    { sector_1 : { progress : Float, rated : RatedTime }
    , sector_2 : { progress : Float, rated : RatedTime }
    , sector_3 : { progress : Float, rated : RatedTime }
    }


type alias MiniSectorProgress =
    { miniSector : LeMans2025MiniSector
    , progress : Float
    }


compute :
    { season : Int }
    ->
        { a
            | fastestLapTime : Duration
            , sector_1_fastest : Duration
            , sector_2_fastest : Duration
            , sector_3_fastest : Duration
            , miniSectorFastest : LeMans2025MiniSectorFastest
        }
    -> { elapsed : Duration, lapCount : Int, cars : RunningOrder }
    -> Standings
compute { season } fastest config =
    let
        carsList =
            RunningOrder.toList config.cars

        leaderCar =
            RunningOrder.leader config.cars

        positionsInClass =
            positionsInClassByCarNumber config.cars

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
                        , classColor = Class.toHexColor season metadata.class
                        , lapsCompleted = lastLap.lap
                        , currentLapTime = currentLap |> Maybe.map .time
                        , currentLapBest = currentLap |> Maybe.map .best
                        , currentLapSectors = currentLap |> Maybe.map extractSectorTimes
                        , currentLapSectorSlots = currentLap |> Maybe.map (extractCurrentSectorSlots fastest timing.sector)
                        , currentLapMiniSectors = currentLap |> Maybe.andThen .miniSectors
                        , currentLapElapsed = timing.currentLapElapsed
                        , currentLapRated =
                            currentLap
                                |> Maybe.map (\lap -> rateTime fastest.fastestLapTime { time = timing.currentLapElapsed, personalBest = lap.best })
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
        { elapsed = config.elapsed
        , laps = config.lapCount
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


{-| デバッグ用: 1台分のラップリストから Standings を組み立てる。

各ラップを1つの Entry として扱い、`metadata.carNumber` にラップ番号文字列をセットする。

-}
fromLaps : { season : Int } -> Car.Metadata -> List Lap -> Standings
fromLaps { season } baseMetadata laps =
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
                        , classColor = Class.toHexColor season baseMetadata.class
                        , lapsCompleted = lap.lap
                        , currentLapTime = Just lap.time
                        , currentLapBest = Just lap.best
                        , currentLapSectors = Just (extractSectorTimes lap)
                        , currentLapSectorSlots = Just (extractCurrentSectorSlots fastest Nothing lap)
                        , currentLapMiniSectors = lap.miniSectors
                        , currentLapElapsed = 0
                        , currentLapRated = Nothing
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
    in
    Standings
        { elapsed = 0
        , laps = laps |> List.map .lap |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


{-| `Entry` のリストから `Standings` を組み立てる。テスト用途などで直接エントリを指定したい場合に使う。
-}
fromList : List Entry -> Standings
fromList entries =
    let
        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { elapsed = 0
        , laps = entries |> List.map .lapsCompleted |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


groupEntriesByClass : SortedList ByPosition Entry -> List ( ClassInfo, SortedList ByPosition Entry )
groupEntriesByClass sortedEntries =
    sortedEntries
        |> SortedList.gatherEqualsBy (.metadata >> .class)
        |> List.map (\( first, rest ) -> ( classInfoOf first, Ordering.byPosition (first :: SortedList.toList rest) ))


{-| エントリからクラスの表示情報を取り出す。
-}
classInfoOf : Entry -> ClassInfo
classInfoOf entry =
    { class = entry.metadata.class
    , name = Class.toString entry.metadata.class
    , color = entry.classColor
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


extractCurrentSectorSlots :
    { a | sector_1_fastest : Duration, sector_2_fastest : Duration, sector_3_fastest : Duration }
    -> Maybe SectorProgress
    -> Lap
    -> CurrentSectorSlots
extractCurrentSectorSlots fastest sectorProgress lap =
    let
        ( s1_progress, s2_progress, s3_progress ) =
            case sectorProgress of
                Just { sector, progress } ->
                    case sector of
                        S1 ->
                            ( progress, 0, 0 )

                        S2 ->
                            ( 100, progress, 0 )

                        S3 ->
                            ( 100, 100, progress )

                Nothing ->
                    ( 100, 100, 100 )
    in
    { sector_1 = { progress = s1_progress, rated = rateTime fastest.sector_1_fastest { time = lap.sector_1, personalBest = lap.s1_best } }
    , sector_2 = { progress = s2_progress, rated = rateTime fastest.sector_2_fastest { time = lap.sector_2, personalBest = lap.s2_best } }
    , sector_3 = { progress = s3_progress, rated = rateTime fastest.sector_3_fastest { time = lap.sector_3, personalBest = lap.s3_best } }
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


toList : Standings -> List Entry
toList (Standings s) =
    SortedList.toList s.entries


toClassList : Standings -> List ( ClassInfo, List Entry )
toClassList (Standings s) =
    s.entriesByClass
        |> List.map (Tuple.mapSecond SortedList.toList)


leader : Standings -> Maybe Entry
leader (Standings s) =
    SortedList.head s.entries


lapCount : Standings -> Int
lapCount (Standings s) =
    s.laps


{-| この Standings が表すレース経過時間。compute に渡した elapsed が焼き込まれている。
-}
elapsed : Standings -> Duration
elapsed (Standings s) =
    s.elapsed


groupCarsByCloseIntervals : Standings -> List (List Entry)
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
