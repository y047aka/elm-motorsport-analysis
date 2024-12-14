module Motorsport.Leaderboard.ViewModel exposing
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
    , sector_1 : Maybe { time : Duration, personalBest : Duration, inProgress : Bool }
    , sector_2 : Maybe { time : Duration, personalBest : Duration, inProgress : Bool }
    , sector_3 : Maybe { time : Duration, personalBest : Duration, inProgress : Bool }
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
            Lap.currentSector raceClock currentLap

        ( sector_1, sector_2, sector_3 ) =
            case currentSector of
                S1 ->
                    ( Just { time = currentLap.sector_1, personalBest = currentLap.s1_best, inProgress = True }
                    , Nothing
                    , Nothing
                    )

                S2 ->
                    ( Just { time = currentLap.sector_1, personalBest = currentLap.s1_best, inProgress = False }
                    , Just { time = currentLap.sector_2, personalBest = currentLap.s2_best, inProgress = True }
                    , Nothing
                    )

                S3 ->
                    ( Just { time = currentLap.sector_1, personalBest = currentLap.s1_best, inProgress = False }
                    , Just { time = currentLap.sector_2, personalBest = currentLap.s2_best, inProgress = False }
                    , Just { time = currentLap.sector_3, personalBest = currentLap.s3_best, inProgress = True }
                    )
    in
    { time = raceClock.elapsed - lastLap.elapsed
    , sector_1 = sector_1
    , sector_2 = sector_2
    , sector_3 = sector_3
    , gap =
        Maybe.map2 (Gap.at clock) leader (Just car)
            |> Maybe.withDefault Gap.None
    , interval =
        Maybe.map2 (Gap.at clock) rival (Just car)
            |> Maybe.withDefault Gap.None
    }
