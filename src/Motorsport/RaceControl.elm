module Motorsport.RaceControl exposing (Model, Msg(..), empty, init, update)

import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock exposing (Clock)



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
                { m | raceClock = Clock.initWithCount newCount (List.map .laps m.cars) }

            else
                m

        NextLap ->
            if m.raceClock.lapCount < m.lapTotal then
                { m | raceClock = Clock.jumpToNextLap (List.map .laps m.cars) m.raceClock }

            else
                m

        PreviousLap ->
            if m.raceClock.lapCount > 0 then
                { m | raceClock = Clock.jumpToPreviousLap (List.map .laps m.cars) m.raceClock }

            else
                m
