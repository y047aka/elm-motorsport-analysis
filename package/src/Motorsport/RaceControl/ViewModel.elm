module Motorsport.RaceControl.ViewModel exposing
    ( ViewModel, ViewModelItem
    , MetaData, Timing
    , init, init_metaData
    )

{-|

@docs ViewModel, ViewModelItem
@docs MetaData, Timing
@docs init, init_metaData

-}

import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap, Sector(..), completedLapsAt)
import Motorsport.RaceControl as RaceControl


type alias ViewModel =
    List ViewModelItem


type alias ViewModelItem =
    { position : Int
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
    , gap : Gap
    , interval : Gap
    }


init : RaceControl.Model -> ViewModel
init { clock, cars } =
    cars
        |> List.indexedMap
            (\index car ->
                let
                    raceClock =
                        { elapsed = Clock.getElapsed clock }

                    lastLap =
                        Maybe.withDefault Lap.empty car.lastLap
                in
                { position = index + 1
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


init_metaData : Car -> Lap -> MetaData
init_metaData { carNumber, class, team, drivers } lastLap =
    { carNumber = carNumber
    , class = class
    , team = team
    , drivers =
        List.map
            (\{ name } ->
                { name = name
                , isCurrentDriver = name == lastLap.driver
                }
            )
            drivers
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
    in
    { time = raceClock.elapsed - lastLap.elapsed
    , sector = currentSector
    , gap =
        Maybe.map2 (Gap.at clock) leader (Just car)
            |> Maybe.withDefault Gap.None
    , interval =
        Maybe.map2 (Gap.at clock) rival (Just car)
            |> Maybe.withDefault Gap.None
    }
