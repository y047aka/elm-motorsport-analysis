module Data.Leaderboard exposing
    ( init
    , view
    )

{-|

@docs init
@docs view

-}

import Data.Leaderboard.Type
import Data.Leaderboard.View
import Html.Styled as Html exposing (Html)
import Motorsport.Car exposing (Car)
import Motorsport.Clock exposing (Clock)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Lap exposing (Lap, completedLapsAt, findLastLapAt)
import UI.SortableData exposing (State)


type alias Leaderboard =
    Data.Leaderboard.Type.Leaderboard


init : Clock -> List Car -> Leaderboard
init raceClock cars =
    let
        sortedCars =
            sortCars raceClock cars
    in
    sortedCars
        |> List.indexedMap
            (\index { car, lastLap } ->
                { position = index + 1
                , driver = car.driverName
                , carNumber = car.carNumber
                , lap = lastLap.lap
                , gap =
                    List.head sortedCars
                        |> Maybe.map (\leader -> Gap.from leader.lastLap lastLap)
                        |> Maybe.withDefault None
                , time = lastLap.time
                , best = lastLap.best
                , history = completedLapsAt raceClock car.laps
                }
            )


sortCars : Clock -> List Car -> List { car : Car, lastLap : Lap }
sortCars raceClock cars =
    cars
        |> List.map
            (\car ->
                let
                    lastLap =
                        findLastLapAt raceClock car.laps
                            |> Maybe.withDefault { carNumber = "", driver = "", lap = 0, time = 0, best = 0, elapsed = 0 }
                in
                { car = car, lastLap = lastLap }
            )
        |> List.sortWith (\a b -> compare a.lastLap b.lastLap)


compare : Lap -> Lap -> Order
compare a b =
    case Basics.compare a.lap b.lap of
        LT ->
            GT

        EQ ->
            Basics.compare a.elapsed b.elapsed

        GT ->
            LT


view : State -> Clock -> { fastestLapTime : Duration, slowestLapTime : Duration } -> (State -> msg) -> Float -> Leaderboard -> Html msg
view =
    Data.Leaderboard.View.view
