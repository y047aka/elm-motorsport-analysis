module Motorsport.Standings exposing
    ( Standings, StandingsEntry
    , SectorProgress, MiniSectorProgress
    , init
    , getCarHistory, getLastLap
    , groupCarsByCloseIntervals
    , getRecentLaps
    )

{-|

@docs Standings, StandingsEntry
@docs SectorProgress, MiniSectorProgress
@docs init

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


type alias Standings =
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
init { elapsed, lapCount, cars } =
    let
        carsList =
            RunningOrder.toList cars

        leaderCar =
            RunningOrder.leader cars

        positionsInClass =
            positionsInClassByCarNumber cars

        raceClock =
            { elapsed = elapsed }

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
                                init_timing elapsed
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
    { laps = lapCount
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


{-| carNumber からラップ履歴を取得する
-}
getCarHistory : String -> Standings -> List Lap
getCarHistory carNumber standings =
    Dict.get carNumber standings.lapHistory
        |> Maybe.withDefault []


{-| carNumber から lastLap を取得する
-}
getLastLap : String -> Standings -> Maybe Lap
getLastLap carNumber standings =
    Dict.get carNumber standings.carLapData
        |> Maybe.andThen .lastLap


type alias TimingState =
    { currentLapElapsed : Duration
    , sector : Maybe SectorProgress
    , miniSector : Maybe MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


init_timing : Duration -> { leader : Maybe Car, rival : Maybe Car } -> Car -> TimingState
init_timing elapsed { leader, rival } car =
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
        Maybe.map2 (Gap.at elapsed) leader (Just car)
            |> Maybe.withDefault Gap.None
    , intervalToAhead =
        Maybe.map2 (Gap.at elapsed) rival (Just car)
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


groupCarsByCloseIntervals : Standings -> List (List StandingsEntry)
groupCarsByCloseIntervals standings =
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
    SortedList.toList standings.entries
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
