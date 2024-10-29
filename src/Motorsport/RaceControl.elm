module Motorsport.RaceControl exposing (Model, Msg(..), empty, init, update)

import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock exposing (Clock, Model(..))
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Time exposing (Posix)



-- MODEL


type alias Model =
    { state : Clock.Model
    , raceClock : Clock
    , lapCount : Int
    , lapTotal : Int
    , cars : List Car
    }


empty : Model
empty =
    { state = Initial
    , raceClock = { elapsed = 0 }
    , lapCount = 0
    , lapTotal = 0
    , cars = []
    }


init : List Car -> Model
init cars =
    { state = Initial
    , raceClock = { elapsed = 0 }
    , lapCount = 0
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
            case ( m.state, m.raceClock.elapsed < 6 * 60 * 60 * 1000 ) of
                ( Started splitTime started, True ) ->
                    let
                        speed =
                            10

                        newElapsed =
                            splitTime + ((Time.posixToMillis now - Time.posixToMillis started) * speed)

                        newClock =
                            { lapCount = lapAt newElapsed (List.map .laps m.cars)
                            , elapsed = newElapsed
                            }
                    in
                    { m
                        | raceClock = { elapsed = newClock.elapsed }
                        , lapCount = newClock.lapCount
                        , cars = updateCars { elapsed = newClock.elapsed } m.cars
                    }

                _ ->
                    m

        Pause ->
            { m | state = Clock.update Clock.Pause m.state }

        Finish ->
            { m | state = Clock.update Clock.Finish m.state }

        _ ->
            let
                lapTimes =
                    List.map .laps m.cars

                newClock =
                    case msg of
                        Add10seconds ->
                            if m.raceClock.elapsed < 6 * 60 * 60 * 1000 then
                                let
                                    newElapsed =
                                        m.raceClock.elapsed + (10 * 1000)
                                in
                                { lapCount = lapAt newElapsed lapTimes
                                , elapsed = newElapsed
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = m.raceClock.elapsed
                                }

                        SetCount newCount ->
                            if newCount >= 0 && newCount <= m.lapTotal then
                                { lapCount = newCount
                                , elapsed = elapsedAt newCount lapTimes
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = m.raceClock.elapsed
                                }

                        NextLap ->
                            if m.lapCount < m.lapTotal then
                                let
                                    newCount =
                                        m.lapCount + 1
                                in
                                { lapCount = newCount
                                , elapsed = elapsedAt newCount lapTimes
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = m.raceClock.elapsed
                                }

                        PreviousLap ->
                            if m.lapCount > 0 then
                                let
                                    newCount =
                                        m.lapCount - 1
                                in
                                { lapCount = newCount
                                , elapsed = elapsedAt newCount lapTimes
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = m.raceClock.elapsed
                                }

                        _ ->
                            { lapCount = 0, elapsed = 0 }
            in
            { m
                | raceClock = { elapsed = newClock.elapsed }
                , lapCount = newClock.lapCount
                , cars = updateCars { elapsed = newClock.elapsed } m.cars
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


lapAt : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Int
lapAt elapsed lapTimes =
    lapTimes
        |> List.filterMap
            (List.Extra.findMap
                (\lap ->
                    if lap.elapsed > elapsed then
                        Just (lap.lap - 1)

                    else
                        Nothing
                )
            )
        |> List.maximum
        |> Maybe.withDefault 0


elapsedAt : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Duration
elapsedAt lapCount lapTimes =
    let
        nextLap =
            lapCount + 1
    in
    lapTimes
        |> List.filterMap
            (List.Extra.findMap
                (\{ lap, elapsed } ->
                    if nextLap == lap then
                        Just elapsed

                    else
                        Nothing
                )
            )
        |> List.minimum
        |> Maybe.map (\elapsed -> elapsed - 1)
        |> Maybe.withDefault 0
