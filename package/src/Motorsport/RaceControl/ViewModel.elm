module Motorsport.RaceControl.ViewModel exposing
    ( ViewModel, ViewModelItem
    , MetaData, Timing
    , init, init_metaData
    , groupCarsByCloseIntervals
    , getRecentLaps
    )

{-|

@docs ViewModel, ViewModelItem
@docs MetaData, Timing
@docs init, init_metaData

@docs groupCarsByCloseIntervals
@docs getRecentLaps

-}

import Dict exposing (Dict)
import List.Extra
import List.NonEmpty as NonEmpty exposing (NonEmpty)
import Motorsport.Car exposing (Car, Status)
import Motorsport.Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap, MiniSector(..), Sector(..), completedLapsAt)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.RaceControl as RaceControl
import SortedList exposing (SortedList)


type alias ViewModel =
    { leadLapNumber : Int
    , items : SortedList ByPosition ViewModelItem
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
                |> NonEmpty.toList
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
                                { leader = Just (NonEmpty.head cars)
                                , rival = List.Extra.getAt (index - 1) (NonEmpty.toList cars)
                                }
                                car
                        , currentLap = car.currentLap
                        , lastLap = car.lastLap
                        , history = completedLapsAt raceClock car.laps
                        }
                    )
    in
    { leadLapNumber = lapCount
    , items = Ordering.byPosition items
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


positionsInClassByCarNumber : NonEmpty Car -> Dict String Int
positionsInClassByCarNumber cars =
    cars
        |> NonEmpty.toList
        |> List.Extra.gatherEqualsBy (.metaData >> .class)
        |> List.concatMap
            (\( firstCar, restCars ) ->
                (firstCar :: restCars)
                    |> List.indexedMap (\index car -> ( car.metaData.carNumber, index + 1 ))
            )
        |> Dict.fromList


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
    SortedList.toList vm.items
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
