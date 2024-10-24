module Motorsport.RaceControl exposing (Model, Msg(..), State(..), empty, init, update)

import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock exposing (Clock)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Time exposing (Posix)



-- MODEL


type alias Model =
    { state : State
    , raceClock : Clock
    , lapTotal : Int
    , cars : List Car
    }


type State
    = Initial
    | Started Duration Posix
    | Paused
    | Finished


empty : Model
empty =
    { state = Initial
    , raceClock = Clock.init
    , lapTotal = 0
    , cars = []
    }


init : List Car -> Model
init cars =
    { state = Initial
    , raceClock = Clock.init
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
    = Start Posix
    | Pause
    | Finish
    | Tick Posix
    | Add10seconds
    | SetCount Int
    | NextLap
    | PreviousLap


update : Msg -> Model -> Model
update msg m =
    case msg of
        Start now ->
            { m | state = Started m.raceClock.elapsed now }

        Tick now ->
            case m.state of
                Started splitTime started ->
                    let
                        speed =
                            10

                        elapsed =
                            splitTime + ((Time.posixToMillis now - Time.posixToMillis started) * speed)

                        newClock =
                            if m.raceClock.elapsed < 6 * 60 * 60 * 1000 then
                                Clock.initWithElapsed elapsed (List.map .laps m.cars)

                            else
                                m.raceClock
                    in
                    { m
                        | raceClock = newClock
                        , cars = updateCars newClock m.cars
                    }

                _ ->
                    m

        Pause ->
            { m | state = Paused }

        Finish ->
            { m | state = Finished }

        _ ->
            let
                newClock =
                    case msg of
                        Add10seconds ->
                            if m.raceClock.elapsed < 6 * 60 * 60 * 1000 then
                                Clock.add (10 * 1000) (List.map .laps m.cars) m.raceClock

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

                        _ ->
                            Clock.init
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
