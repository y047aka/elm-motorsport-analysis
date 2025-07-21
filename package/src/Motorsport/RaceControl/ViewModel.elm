module Motorsport.RaceControl.ViewModel exposing
    ( ViewModel, ViewModelItem
    , MetaData, Timing
    , init, init_metaData
    , getLeadLapNumber
    , groupCarsByCloseIntervals
    , getRecentLaps
    )

{-|

@docs ViewModel, ViewModelItem
@docs MetaData, Timing
@docs init, init_metaData

@docs getLeadLapNumber
@docs groupCarsByCloseIntervals
@docs getRecentLaps

-}

import Dict exposing (Dict)
import List.Extra
import List.NonEmpty as NonEmpty exposing (NonEmpty)
import Motorsport.Car exposing (Car, Status(..))
import Motorsport.Class as Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap, MiniSector(..), Sector(..), completedLapsAt)
import Motorsport.RaceControl as RaceControl


type alias ViewModel =
    { leadLapNumber : Int
    , items : NonEmpty ViewModelItem
    }


type alias ViewModelItem =
    { position : Int
    , positionInClass : Int
    , status : Status
    , metaData : MetaData
    , lap : Int
    , timing : Timing
    , currentLap : Maybe Lap
    , lastLap : Maybe Lap
    , history : List Lap
    }


type alias MetaData =
    { carNumber : String
    , class : Class
    , team : String
    , drivers : List Driver
    }


type alias Timing =
    { time : Duration
    , sector : Maybe ( Sector, Float )
    , miniSector : Maybe ( MiniSector, Float )
    , gap : Gap
    , interval : Gap
    }


init : RaceControl.Model -> ViewModel
init { clock, lapCount, cars } =
    let
        positionsInClass =
            positionsInClassByCarNumber cars

        items =
            cars
                |> List.indexedMap
                    (\index car ->
                        let
                            raceClock =
                                { elapsed = Clock.getElapsed clock }

                            positionInClass =
                                Dict.get car.metaData.carNumber positionsInClass
                                    |> Maybe.withDefault 1

                            lastLap =
                                Maybe.withDefault Lap.empty car.lastLap
                        in
                        { position = index + 1
                        , positionInClass = positionInClass
                        , status = car.status
                        , metaData = init_metaData car lastLap
                        , lap = lastLap.lap
                        , timing =
                            init_timing clock
                                { leader = List.head cars
                                , rival = List.Extra.getAt (index - 1) cars
                                }
                                car
                        , currentLap = car.currentLap
                        , lastLap = car.lastLap
                        , history = completedLapsAt raceClock car.laps
                        }
                    )
                |> NonEmpty.fromList
                |> Maybe.withDefault (NonEmpty.singleton (defaultViewModelItem clock))
    in
    { leadLapNumber = lapCount
    , items = items
    }


defaultViewModelItem : Clock.Model -> ViewModelItem
defaultViewModelItem clock =
    { position = 1
    , positionInClass = 1
    , status = Racing
    , metaData =
        { carNumber = "0"
        , class = Class.none
        , team = ""
        , drivers = []
        }
    , lap = 0
    , timing =
        { time = 0
        , sector = Nothing
        , miniSector = Nothing
        , gap = Gap.None
        , interval = Gap.None
        }
    , currentLap = Nothing
    , lastLap = Nothing
    , history = []
    }


init_metaData : Car -> Lap -> MetaData
init_metaData { metaData } lastLap =
    { carNumber = metaData.carNumber
    , class = metaData.class
    , team = metaData.team
    , drivers =
        List.map
            (\{ name } ->
                { name = name
                , isCurrentDriver = name == lastLap.driver
                }
            )
            metaData.drivers
    }


init_timing : Clock.Model -> { leader : Maybe Car, rival : Maybe Car } -> Car -> Timing
init_timing clock { leader, rival } car =
    let
        raceClock =
            { elapsed = Clock.getElapsed clock }

        currentLap =
            Maybe.withDefault Lap.empty car.currentLap

        lastLap =
            Maybe.withDefault Lap.empty car.lastLap

        currentSector =
            case Lap.currentSector raceClock currentLap of
                S1 ->
                    Just ( S1, min 100 ((toFloat (raceClock.elapsed - lastLap.elapsed) / toFloat currentLap.sector_1) * 100) )

                S2 ->
                    Just ( S2, min 100 ((toFloat (raceClock.elapsed - (lastLap.elapsed + currentLap.sector_1)) / toFloat currentLap.sector_2) * 100) )

                S3 ->
                    Just ( S3, min 100 ((toFloat (raceClock.elapsed - (lastLap.elapsed + currentLap.sector_1 + currentLap.sector_2)) / toFloat currentLap.sector_3) * 100) )

        currentMiniSector =
            Lap.miniSectorProgressAt raceClock ( currentLap, lastLap )
    in
    { time = raceClock.elapsed - lastLap.elapsed
    , sector = currentSector
    , miniSector = currentMiniSector
    , gap =
        Maybe.map2 (Gap.at clock) leader (Just car)
            |> Maybe.withDefault Gap.None
    , interval =
        Maybe.map2 (Gap.at clock) rival (Just car)
            |> Maybe.withDefault Gap.None
    }


positionsInClassByCarNumber : List Car -> Dict String Int
positionsInClassByCarNumber cars =
    cars
        |> List.Extra.gatherEqualsBy (.metaData >> .class)
        |> List.concatMap
            (\( firstCar, restCars ) ->
                (firstCar :: restCars)
                    |> List.indexedMap (\index car -> ( car.metaData.carNumber, index + 1 ))
            )
        |> Dict.fromList


getLeadLapNumber : NonEmpty ViewModelItem -> Int
getLeadLapNumber items =
    NonEmpty.head items |> .lap


groupCarsByCloseIntervals : ViewModel -> List (List ViewModelItem)
groupCarsByCloseIntervals vm =
    let
        isCloseToNext current =
            case current.timing.interval of
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
    vm.items
        |> NonEmpty.toList
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
