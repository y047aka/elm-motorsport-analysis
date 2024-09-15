module Motorsport.RaceControl exposing (Model, Msg(..), empty, init, update)

import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock exposing (Clock)
import Motorsport.Lap exposing (findCurrentLap)



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
    = SetCount Int
    | NextLap
    | PreviousLap


update : Msg -> Model -> Model
update msg m =
    case msg of
        SetCount newCount ->
            if newCount >= 0 && newCount <= m.lapTotal then
                let
                    now =
                        Clock.initWithCount newCount (List.map .laps m.cars)
                in
                { m
                    | raceClock = now
                    , cars = updateCars now m.cars
                }

            else
                m

        NextLap ->
            if m.raceClock.lapCount < m.lapTotal then
                let
                    now =
                        Clock.jumpToNextLap (List.map .laps m.cars) m.raceClock
                in
                { m
                    | raceClock = now
                    , cars = updateCars now m.cars
                }

            else
                m

        PreviousLap ->
            if m.raceClock.lapCount > 0 then
                let
                    now =
                        Clock.jumpToPreviousLap (List.map .laps m.cars) m.raceClock
                in
                { m
                    | raceClock = now
                    , cars = updateCars now m.cars
                }

            else
                m


updateCars : Clock -> List Car -> List Car
updateCars raceClock cars =
    cars
        |> List.map
            (\car ->
                let
                    currentDriver =
                        findCurrentLap raceClock car.laps
                            |> Maybe.map .driver
                            |> Maybe.withDefault ""
                in
                { car | currentDriver = currentDriver }
            )
