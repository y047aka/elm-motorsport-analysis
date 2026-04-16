module Motorsport.Standings exposing
    ( Standings, StandingsEntry
    , SectorProgress, MiniSectorProgress
    , init, fromLaps, fromList
    , toList, toClassList, leader, lapCount
    , getCarHistory, getLastLap
    , groupCarsByCloseIntervals
    , getRecentLaps
    )

{-|

@docs Standings, StandingsEntry
@docs SectorProgress, MiniSectorProgress
@docs init, fromLaps, fromList

@docs toList, toClassList, leader, lapCount

@docs getCarHistory, getLastLap

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
import Motorsport.Lap as Lap exposing (Lap, completedLapsAt)
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
        , carLapData : Dict String { currentLap : Maybe Lap, lastLap : Maybe Lap }
        }


type alias StandingsEntry =
    { position : Int
    , positionInClass : Int
    , status : Status
    , metadata : Car.Metadata
    , lapsCompleted : Int
    , currentLap : Maybe Lap
    , currentLapElapsed : Duration
    , sector : Maybe SectorProgress
    , miniSector : Maybe MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    , currentLapProgress : Float
    , lastLapTime : Maybe Duration
    , bestLapTime : Maybe Duration
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


init : { elapsed : Duration, lapCount : Int, cars : RunningOrder } -> Standings
init config =
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
                        , currentLap = car.currentLap
                        , currentLapElapsed = timing.currentLapElapsed
                        , sector = timing.sector
                        , miniSector = timing.miniSector
                        , gapToLeader = timing.gapToLeader
                        , intervalToAhead = timing.intervalToAhead
                        , currentLapProgress =
                            car.currentLap
                                |> Maybe.map (\lap -> min 1.0 (toFloat timing.currentLapElapsed / toFloat lap.time))
                                |> Maybe.withDefault 0
                        , lastLapTime = car.lastLap |> Maybe.map .time
                        , bestLapTime = car.lastLap |> Maybe.map .best
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
        , carLapData =
            carsList
                |> List.map (\car -> ( car.metadata.carNumber, { currentLap = car.currentLap, lastLap = car.lastLap } ))
                |> Dict.fromList
        }


{-| デバッグ用: 1台分のラップリストから Standings を組み立てる。

各ラップを1つの StandingsEntry として扱い、`metadata.carNumber` にラップ番号文字列をセットする。
`lapHistory` / `carLapData` はラップ番号文字列をキーとして構築されるため、不変条件が保たれる。

-}
fromLaps : Car.Metadata -> List Lap -> Standings
fromLaps baseMetadata laps =
    let
        entries =
            laps
                |> List.indexedMap
                    (\index lap ->
                        { position = index + 1
                        , positionInClass = index + 1
                        , status = Car.Racing
                        , metadata = { baseMetadata | carNumber = String.fromInt lap.lap }
                        , lapsCompleted = lap.lap
                        , currentLap = Just lap
                        , currentLapElapsed = 0
                        , sector = Nothing
                        , miniSector = Nothing
                        , gapToLeader = Gap.None
                        , intervalToAhead = Gap.None
                        , currentLapProgress = 0
                        , lastLapTime = Just lap.time
                        , bestLapTime = Just lap.best
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
        , carLapData =
            laps
                |> List.map (\lap -> ( lapKey lap, { currentLap = Just lap, lastLap = Just lap } ))
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
        { laps = entries |> List.filterMap (.currentLap >> Maybe.map .lap) |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass =
            sortedEntries
                |> SortedList.gatherEqualsBy (.metadata >> .class)
                |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
        , lapHistory = Dict.empty
        , carLapData = Dict.empty
        }


{-| carNumber からラップ履歴を取得する
-}
getCarHistory : String -> Standings -> List Lap
getCarHistory carNumber (Standings s) =
    Dict.get carNumber s.lapHistory
        |> Maybe.withDefault []


{-| carNumber から lastLap を取得する
-}
getLastLap : String -> Standings -> Maybe Lap
getLastLap carNumber (Standings s) =
    Dict.get carNumber s.carLapData
        |> Maybe.andThen .lastLap


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


getRecentLaps : Int -> { laps : Int } -> List Lap -> List Lap
getRecentLaps n { laps } lapList =
    let
        targetRange =
            List.range (laps - n) laps
    in
    lapList
        |> List.filter (\lap -> List.member lap.lap targetRange)
        |> List.sortBy .lap
