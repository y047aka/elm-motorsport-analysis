module Motorsport.RaceControl exposing (Model, Msg(..), empty, init, update)

import List.Extra
import Motorsport.Car as Car exposing (Car)
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Time exposing (Posix, millisToPosix)



-- MODEL


type alias Model =
    { clock : Clock.Model
    , lapCount : Int
    , lapTotal : Int
    , timeLimit : Int
    , cars : List Car
    }


empty : Model
empty =
    { clock = Initial
    , lapCount = 0
    , lapTotal = 0
    , timeLimit = 0
    , cars = []
    }


init : List Car -> Model
init cars =
    { clock = Initial
    , lapCount = 0
    , lapTotal = calcLapTotal cars
    , timeLimit = calcTimeLimit cars
    , cars = cars
    }


calcLapTotal : List Car -> Int
calcLapTotal =
    List.map (.laps >> List.length)
        >> List.maximum
        >> Maybe.withDefault 0


calcTimeLimit : List Car -> Duration
calcTimeLimit =
    List.map (.laps >> List.Extra.last >> Maybe.map .elapsed)
        >> List.filterMap identity
        >> List.maximum
        >> Maybe.map (\timeLimit -> (timeLimit // (60 * 60 * 1000)) * 60 * 60 * 1000)
        >> Maybe.withDefault 0



-- UPDATE


type Msg
    = Start Posix
    | Pause Posix
    | Finish Posix
    | Tick Posix
    | Add10seconds
    | SetCount Int
    | NextLap
    | PreviousLap


update : Msg -> Model -> Model
update msg m =
    case msg of
        Start now ->
            { m | clock = Clock.update now Clock.Start m.clock }

        Tick now ->
            case m.clock of
                Started splitTime { startedAt } ->
                    if Clock.calcElapsed startedAt now splitTime < m.timeLimit then
                        let
                            newElapsed =
                                Clock.calcElapsed startedAt now splitTime

                            newClock =
                                { lapCount = lapAt newElapsed (List.map .laps m.cars)
                                , elapsed = newElapsed
                                }
                        in
                        { m
                            | clock = Clock.update now Clock.Tick m.clock
                            , lapCount = newClock.lapCount
                            , cars = updateCars m.timeLimit { elapsed = newClock.elapsed } m.cars
                        }

                    else
                        m

                _ ->
                    m

        Pause now ->
            { m | clock = Clock.update now Clock.Pause m.clock }

        Finish now ->
            { m | clock = Clock.update now Clock.Finish m.clock }

        _ ->
            let
                dummyPosix =
                    millisToPosix 0

                { lapCount, elapsed } =
                    let
                        elapsed_ =
                            Clock.getElapsed m.clock

                        lapTimes =
                            List.map .laps m.cars
                    in
                    case msg of
                        Add10seconds ->
                            if elapsed_ < m.timeLimit then
                                let
                                    newElapsed =
                                        elapsed_ + (10 * 1000)
                                in
                                { lapCount = lapAt newElapsed lapTimes
                                , elapsed = newElapsed
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = elapsed_
                                }

                        SetCount newCount ->
                            if newCount >= 0 && newCount <= m.lapTotal then
                                { lapCount = newCount
                                , elapsed = elapsedAt newCount lapTimes
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = elapsed_
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
                                , elapsed = elapsed_
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
                                , elapsed = elapsed_
                                }

                        _ ->
                            { lapCount = 0, elapsed = 0 }
            in
            { m
                | clock = Clock.update dummyPosix (Clock.Set elapsed) m.clock
                , lapCount = lapCount
                , cars = updateCars m.timeLimit { elapsed = elapsed } m.cars
            }


type alias Clock =
    { elapsed : Duration }


updateCars : Duration -> Clock -> List Car -> List Car
updateCars timeLimit raceClock cars =
    cars
        |> List.map (Car.updateWithClock { elapsed = raceClock.elapsed, timeLimit = timeLimit } )
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
