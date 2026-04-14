module Motorsport.Standings exposing
    ( Standings, StandingsEntry
    , TimingState, SectorProgress, MiniSectorProgress
    , init
    , groupCarsByCloseIntervals
    , getRecentLaps
    )

{-|

@docs Standings, StandingsEntry
@docs TimingState, SectorProgress, MiniSectorProgress
@docs init

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
    { leadLapNumber : Int
    , entries : SortedList ByPosition StandingsEntry
    , entriesByClass : List ( Class, SortedList ByPosition StandingsEntry )
    }


type alias StandingsEntry =
    { position : Int
    , positionInClass : Int
    , status : Status
    , metadata : Car.Metadata
    , lap : Int
    , timing : TimingState
    , currentLap : Maybe Lap
    , lastLap : Maybe Lap
    , history : List Lap
    , currentDriver : Maybe Driver
    }


type alias TimingState =
    { currentLapElapsed : Duration
    , sector : Maybe SectorProgress
    , miniSector : Maybe MiniSectorProgress
    , gapToLeader : Gap
    , intervalToPrevious : Gap
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
                        in
                        { position = index + 1
                        , positionInClass = positionInClass
                        , status = car.status
                        , metadata = metadata
                        , lap = lastLap.lap
                        , timing =
                            init_timing elapsed
                                { leader = Just leaderCar
                                , rival = List.Extra.getAt (index - 1) carsList
                                }
                                car
                        , currentLap = car.currentLap
                        , lastLap = car.lastLap
                        , history = completedLapsAt raceClock car.laps
                        , currentDriver = car.currentDriver
                        }
                    )

        sortedEntries =
            Ordering.byPosition entries
    in
    { leadLapNumber = lapCount
    , entries = sortedEntries
    , entriesByClass =
        sortedEntries
            |> SortedList.gatherEqualsBy (.metadata >> .class)
            |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
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
    , intervalToPrevious =
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
            case current.timing.intervalToPrevious of
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


getRecentLaps : Int -> { leadLapNumber : Int } -> List Lap -> List Lap
getRecentLaps n { leadLapNumber } laps =
    let
        targetRange =
            List.range (leadLapNumber - n) leadLapNumber
    in
    laps
        |> List.filter (\lap -> List.member lap.lap targetRange)
        |> List.sortBy .lap
