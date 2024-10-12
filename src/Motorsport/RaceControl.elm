module Motorsport.RaceControl exposing (Model, Msg(..), empty, init, update)

import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock exposing (Clock)
import Motorsport.Lap as Lap



-- MODEL


type alias Model =
    { raceClock : Clock
    , lapTotal : Int
    , cars : List Car
    }


empty : Model
empty =
    { raceClock = Clock.init
    , lapTotal = 0
    , cars = []
    }


init : List Car -> Model
init cars =
    { raceClock = Clock.init
    , lapTotal = calcLapTotal cars
    , cars = cars
    }


calcLapTotal : List Car -> Int
calcLapTotal =
    List.map (.laps >> List.length)
        >> List.maximum
        >> Maybe.withDefault 0



-- UPDATE


type Msg
    = Add10seconds
    | Subtract10seconds
    | SetCount Int
    | NextLap
    | PreviousLap


update : Msg -> Model -> Model
update msg m =
    let
        newClock =
            case msg of
                Add10seconds ->
                    if m.raceClock.elapsed < 6 * 60 * 60 * 1000 then
                        Clock.add (10 * 1000) (List.map .laps m.cars) m.raceClock

                    else
                        m.raceClock

                Subtract10seconds ->
                    if m.raceClock.elapsed > 0 then
                        Clock.subtract (10 * 1000) (List.map .laps m.cars) m.raceClock

                    else
                        m.raceClock

                SetCount newCount ->
                    if newCount >= 0 && newCount <= m.lapTotal then
                        Clock.initWithCount newCount (List.map .laps m.cars)

                    else
                        m.raceClock

                NextLap ->
                    if m.raceClock.lapCount < m.lapTotal then
                        Clock.jumpToNextLap (List.map .laps m.cars) m.raceClock

                    else
                        m.raceClock

                PreviousLap ->
                    if m.raceClock.lapCount > 0 then
                        Clock.jumpToPreviousLap (List.map .laps m.cars) m.raceClock

                    else
                        m.raceClock
    in
    { m
        | raceClock = newClock
        , cars = updateCars newClock m.cars
    }


updateCars : Clock -> List Car -> List Car
updateCars raceClock cars =
    cars
        |> List.map
            (\car ->
                { car
                    | currentLap = Lap.findCurrentLap raceClock car.laps
                    , lastLap = Lap.findLastLapAt raceClock car.laps
                }
            )
        |> List.sortWith
            (\a b ->
                Maybe.map2 (Lap.compareAt raceClock) a.currentLap b.currentLap
                    |> Maybe.withDefault EQ
            )
